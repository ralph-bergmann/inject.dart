import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:test/test.dart';

/// Verifies that [generatedSource] contains no analyzer errors of
/// [DiagnosticSeverity.ERROR] severity.
///
/// Warnings, infos and hints are ignored.
///
/// [fileName] is the virtual file name (e.g. `'test.inject.dart'`) used for
/// import resolution within the sandbox.
///
/// [additionalSources] is an optional map of additional virtual source files
/// (e.g. the fixture input that the generated code imports). Keys are file
/// names, values are file contents.
Future<void> expectNoAnalyzerErrors(
  String generatedSource, {
  required String fileName,
  Map<String, String> additionalSources = const {},
}) async {
  if (generatedSource.isEmpty) {
    fail('generatedSource is empty — nothing to analyze for $fileName.');
  }
  final List<Diagnostic> errors = await _analyzeSource(
    generatedSource,
    fileName: fileName,
    additionalSources: additionalSources,
  );
  if (errors.isEmpty) {
    return;
  }
  fail(_formatErrors(errors, generatedSource, fileName));
}

/// Verifies that [generatedSource] produces analyzer errors matching [matching].
///
/// The test fails if (a) no errors are found, or (b) [matching] does not hold.
/// Use this to write a green TDD proof-test for a known generator bug.
///
/// [matching] is evaluated against the full [List<Diagnostic>] of ERROR-level
/// diagnostics. Example:
/// ```dart
/// matching: anyElement(
///   predicate<Diagnostic>((e) => e.message.contains('return type')),
/// )
/// ```
Future<void> expectAnalyzerErrors(
  String generatedSource, {
  required String fileName,
  required Matcher matching,
  Map<String, String> additionalSources = const {},
}) async {
  if (generatedSource.isEmpty) {
    fail('generatedSource is empty — nothing to analyze for $fileName.');
  }
  final List<Diagnostic> errors = await _analyzeSource(
    generatedSource,
    fileName: fileName,
    additionalSources: additionalSources,
  );
  expect(
    errors,
    isNotEmpty,
    reason: 'expectAnalyzerErrors requires at least one ERROR-level diagnostic',
  );
  expect(errors, matching);
}

// ---------------------------------------------------------------------------
// Private implementation
// ---------------------------------------------------------------------------

/// Runs the Dart analyzer over [generatedSource] and returns all diagnostics
/// with [DiagnosticSeverity.ERROR] severity.
Future<List<Diagnostic>> _analyzeSource(
  String generatedSource, {
  required String fileName,
  required Map<String, String> additionalSources,
}) async {
  if (additionalSources.containsKey(fileName)) {
    throw ArgumentError.value(
      fileName,
      'fileName',
      'additionalSources must not contain a key equal to fileName '
          '(would silently overwrite the primary overlay).',
    );
  }
  for (final String key in additionalSources.keys) {
    if (key.contains('..') || key.startsWith('/') || key.startsWith(r'\')) {
      throw ArgumentError.value(
        key,
        'additionalSources key',
        'must be a relative path inside the sandbox '
            '(no parent traversal or absolute paths).',
      );
    }
  }

  // OverlayResourceProvider lets the analyzer read real package: URIs from the
  // physical file system while serving virtual files via in-memory overlays.
  final OverlayResourceProvider overlay = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);

  // Place virtual files in a sandbox directory that sits inside the package
  // root so the context locator can walk up the directory tree and discover
  // `.dart_tool/package_config.json` automatically, which makes all
  // `package:` imports resolvable without any additional configuration.
  //
  // The directory does not need to exist on disk — OverlayResourceProvider
  // makes it visible to the analyzer as long as files inside it have overlays.
  final String packageRoot = _findPackageRoot();
  final String sandboxDir = '$packageRoot/test/_analyzer_sandbox';
  final String filePath = '$sandboxDir/$fileName';

  overlay.setOverlay(filePath, content: generatedSource, modificationStamp: 0);
  final List<String> additionalPaths = <String>[];
  for (final MapEntry<String, String> entry in additionalSources.entries) {
    final String additionalPath = '$sandboxDir/${entry.key}';
    overlay.setOverlay(
      additionalPath,
      content: entry.value,
      modificationStamp: 0,
    );
    additionalPaths.add(additionalPath);
  }

  // Include every overlay path so the analyzer can resolve `part`/`part of`
  // relationships between primary and additional sources (e.g. a `.factory.dart`
  // part file whose host library lives in additionalSources).
  final AnalysisContextCollection collection = AnalysisContextCollection(
    includedPaths: [filePath, ...additionalPaths],
    resourceProvider: overlay,
  );

  try {
    final AnalysisSession session;
    try {
      session = collection.contextFor(filePath).currentSession;
    } on StateError catch (e) {
      fail(
        'No analysis context for $filePath. '
        'Ensure `dart pub get` has been run in the package so '
        '`.dart_tool/package_config.json` exists. ($e)',
      );
    }
    final SomeErrorsResult result = await session.getErrors(filePath);
    if (result is! ErrorsResult) {
      fail(
        'Analyzer could not produce errors for $filePath: '
        'got ${result.runtimeType} instead of ErrorsResult.',
      );
    }
    return result.diagnostics
        .where((Diagnostic d) => d.diagnosticCode.severity == DiagnosticSeverity.ERROR)
        .toList();
  } finally {
    await collection.dispose();
  }
}

/// Walks up from [Directory.current] looking for the nearest directory that
/// contains a `pubspec.yaml`. Falls back with a clear error when the test was
/// invoked from outside any Dart package (e.g. the monorepo root without a
/// `pubspec.yaml` of its own).
String _findPackageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail(
        'analyzer_check_helper: could not locate a `pubspec.yaml` walking up '
        'from ${Directory.current.path}. Run the test from inside the package '
        'directory (e.g. `cd packages/inject_generator && dart test`).',
      );
    }
    dir = parent;
  }
}

/// Formats a list of analyzer errors into a readable failure message.
String _formatErrors(
  List<Diagnostic> errors,
  String source,
  String fileName,
) {
  final StringBuffer buffer = StringBuffer();
  for (final Diagnostic err in errors) {
    final int offset = err.offset;
    final int lineStart = source.lastIndexOf('\n', offset) + 1;
    final int lineEnd = source.indexOf('\n', offset);
    final String line = source.substring(
      lineStart,
      lineEnd == -1 ? source.length : lineEnd,
    );
    buffer
      ..writeln(
        'Analyzer error in $fileName at offset $offset-${offset + err.length}:',
      )
      ..writeln(
        '  [${err.diagnosticCode.lowerCaseName}] ${err.message}',
      )
      ..writeln('Source line:')
      ..writeln('  $line');
  }
  return buffer.toString();
}
