import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/build/codegen_builder.dart';
import 'package:inject_generator/src/build/summary_builder.dart';
import 'package:inject_generator/src/summary.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

const rootPackage = 'inject_generator';

/// Matches a [LogRecord] on its [level] and [message].
Matcher logRecord(Level level, String message) => _LogRecordMatcher(level, message);

class SummaryTestBed extends _TestBed {
  @override
  SummaryTestBed({required super.inputAssetId}) : super(builder: const InjectSummaryBuilder());
}

class CodegenTestBed extends _TestBed {
  @override
  CodegenTestBed({required super.inputAssetId, required super.input}) : super(builder: const InjectCodegenBuilder());

  /// Compare the generated code with the code in the file.
  Future<void> compare() async {
    final reader = await PackageAssetReader.currentIsolate(rootPackage: rootPackage);
    final content = await reader.readAsString(genFiles.keys.first);
    expect(genFiles.length, 1);
    expect(genFiles.values.first, content);
  }
}

/// Makes testing the [InjectSummaryBuilder] convenient.
class _TestBed {
  /// AssetId of the content to test for the builder.
  final AssetId inputAssetId;

  /// The content to test for the builder.
  final String? input;

  final Builder builder;

  /// Log records written by the builder.
  final List<LogRecord> logRecords = <LogRecord>[];

  final _TestingAssetWriter _writer = _TestingAssetWriter();

  _TestBed({required this.inputAssetId, this.input, required this.builder});

  /// Generated library summaries keyed by their paths.
  Map<AssetId, LibrarySummary> get summaries => _writer.summaries;

  /// Generated code keyed by their paths.
  Map<AssetId, String> get genFiles => _writer.genFiles;

  /// Generated stuff as String keyed by their paths
  Map<AssetId, String> get content => _writer.assets.map((key, value) => MapEntry(key, utf8.decode(value)));

  /// Verifies that [logRecords] contains a message with the desired [level] and
  /// [message].
  void expectLogRecord(Level level, String message) {
    expect(logRecords, contains(logRecord(level, message)));
  }

  /// Verifies that [logRecords] contains [expectedCount] number of messages
  /// that match [message].
  void expectLogRecordCount(Level level, String message, int expectedCount) {
    final matcher = logRecord(level, message);
    final count = logRecords.map((record) => matcher.matches(record, {})).where((matches) => matches).length;
    expect(
      count,
      expectedCount,
      reason: 'Expected the log to $expectedCount messages with "$message" '
          'but found $count. The log contains:\n${logRecords.join('\n')}',
    );
  }

  /// Prints recorded log messages to standard output.
  ///
  /// This method is meant to be used for debugging tests.
  void printLog() {
    for (final record in logRecords) {
      print(record);
    }
  }

  /// Runs the [InjectSummaryBuilder].
  Future<void> run() async {
    final reader = await PackageAssetReader.currentIsolate(rootPackage: rootPackage);

    final content = input ?? await reader.readAsString(inputAssetId);
    await testBuilder(
      builder,
      {inputAssetId.toString(): content},
      isInput: (assetId) => assetId.startsWith(rootPackage),
      rootPackage: rootPackage,
      reader: reader,
      writer: _writer,
      onLog: logRecords.add,
    );
  }
}

class _LogRecordMatcher extends Matcher {
  final Level level;
  final String message;

  _LogRecordMatcher(this.level, this.message);

  @override
  Description describe(Description description) {
    description.add('log record of level $level with message "$message".');
    return description;
  }

  @override
  bool matches(item, Map matchState) => item is LogRecord && item.level == level && item.message.contains(message);
}

class _TestingAssetWriter extends InMemoryAssetWriter {
  final Map<AssetId, LibrarySummary> summaries = <AssetId, LibrarySummary>{};
  final Map<AssetId, String> genFiles = <AssetId, String>{};

  _TestingAssetWriter();

  @override
  Future writeAsString(
    AssetId id,
    String contents, {
    Encoding encoding = utf8,
  }) async {
    await super.writeAsString(id, contents, encoding: encoding);
    if (id.path.endsWith('.inject.summary')) {
      summaries[id] = LibrarySummary.fromJson(json.decode(contents));
    }
    if (id.path.endsWith('.inject.dart')) {
      genFiles[id] = contents;
    }
  }
}
