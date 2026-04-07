import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/logging/source_snippet.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  setUpAll(() {
    hierarchicalLoggingEnabled = true;
  });
  group('DiagnosticSeverity', () {
    test('has error and warning values', () {
      expect(
        DiagnosticSeverity.values,
        containsAll([DiagnosticSeverity.error, DiagnosticSeverity.warning, DiagnosticSeverity.info]),
      );
    });
  });

  group('DiagnosticMessage', () {
    test('formats error message with file path and line number', () {
      const msg = DiagnosticMessage(
        severity: DiagnosticSeverity.error,
        filePath: 'lib/src/service.dart',
        line: 12,
        column: 0,
        message: 'Missing binding: PaymentService is required by CheckoutComponent.',
        suggestion: 'Add @provides PaymentService to your PaymentModule.',
      );

      expect(
        msg.formattedMessage,
        equals(
          '[inject_generator] ERROR in lib/src/service.dart:12:0\n'
          '  Missing binding: PaymentService is required by CheckoutComponent.\n'
          '  → Add @provides PaymentService to your PaymentModule.',
        ),
      );
    });

    test('formats warning message with file path and line number', () {
      const msg = DiagnosticMessage(
        severity: DiagnosticSeverity.warning,
        filePath: 'lib/src/external.dart',
        line: 5,
        column: 0,
        message: "Class 'ExternalService' is used in the dependency graph but has no @inject annotation.",
        suggestion: 'Add @inject to make this explicit, or use @provides in a module.',
      );

      expect(
        msg.formattedMessage,
        equals(
          '[inject_generator] WARNING in lib/src/external.dart:5:0\n'
          "  Class 'ExternalService' is used in the dependency graph but has no @inject annotation.\n"
          '  → Add @inject to make this explicit, or use @provides in a module.',
        ),
      );
    });

    test('indents multiline message content on every line', () {
      const msg = DiagnosticMessage(
        severity: DiagnosticSeverity.error,
        filePath: 'lib/src/service.dart',
        line: 12,
        column: 0,
        message: 'First line\nSecond line',
        suggestion: 'Apply fix.',
      );

      expect(
        msg.formattedMessage,
        equals(
          '[inject_generator] ERROR in lib/src/service.dart:12:0\n'
          '  First line\n'
          '  Second line\n'
          '  → Apply fix.',
        ),
      );
    });

    test('indents multiline suggestions on every line', () {
      const msg = DiagnosticMessage(
        severity: DiagnosticSeverity.warning,
        filePath: 'lib/src/external.dart',
        line: 5,
        column: 0,
        message: 'Problem description.',
        suggestion: 'Do this first.\nThen do that.',
      );

      expect(
        msg.formattedMessage,
        equals(
          '[inject_generator] WARNING in lib/src/external.dart:5:0\n'
          '  Problem description.\n'
          '  → Do this first.\n'
          '  → Then do that.',
        ),
      );
    });

    test('is immutable with const constructor', () {
      // If this compiles, the const constructor works.
      const msg = DiagnosticMessage(
        severity: DiagnosticSeverity.error,
        filePath: 'a.dart',
        line: 1,
        column: 0,
        message: 'msg',
        suggestion: 'fix',
      );
      expect(msg.severity, DiagnosticSeverity.error);
      expect(msg.filePath, 'a.dart');
      expect(msg.line, 1);
      expect(msg.message, 'msg');
      expect(msg.suggestion, 'fix');
    });

    test('formats error message with snippet', () {
      const snippet = SourceSnippet(
        lines: ['class Foo {', '  @inject', '  @async', '  const Foo() {}', '}'],
        errorLineIndex: 2,
        highlightColumn: 2,
        highlightLength: 6,
        startLineNumber: 3,
      );

      const msg = DiagnosticMessage(
        severity: DiagnosticSeverity.error,
        filePath: 'lib/src/service.dart',
        line: 5,
        column: 3,
        message: 'Duplicate annotation.',
        suggestion: 'Remove one.',
        snippet: snippet,
      );

      expect(
        msg.formattedMessage,
        equals(
          '[inject_generator] ERROR in lib/src/service.dart:5:3\n'
          '  ╷\n'
          '3 │ class Foo {\n'
          '4 │   @inject\n'
          '5 │   @async\n'
          '  │   ^^^^^^\n'
          '6 │   const Foo() {}\n'
          '7 │ }\n'
          '  ╵\n'
          '  Duplicate annotation.\n'
          '  → Remove one.',
        ),
      );
    });

    test('formats message without snippet unchanged', () {
      const msg = DiagnosticMessage(
        severity: DiagnosticSeverity.warning,
        filePath: 'lib/src/a.dart',
        line: 1,
        column: 0,
        message: 'Some warning.',
      );

      expect(
        msg.formattedMessage,
        equals(
          '[inject_generator] WARNING in lib/src/a.dart:1:0\n'
          '  Some warning.',
        ),
      );
    });
  });

  group('DiagnosticReporter', () {
    late DiagnosticReporter reporter;

    setUp(() {
      reporter = DiagnosticReporter();
    });

    test('starts with no messages and hasErrors is false', () {
      expect(reporter.messages, isEmpty);
      expect(reporter.hasErrors, isFalse);
    });

    test('error() adds error-severity message', () {
      reporter.error(filePath: 'lib/a.dart', line: 10, column: 0, message: 'Problem found.', suggestion: 'Fix it.');

      final DiagnosticMessage first = reporter.messages.first;
      expect(reporter.messages, hasLength(1));
      expect(first.severity, DiagnosticSeverity.error);
      expect(first.filePath, 'lib/a.dart');
      expect(first.line, 10);
      expect(first.message, 'Problem found.');
      expect(first.suggestion, 'Fix it.');
    });

    test('warning() adds warning-severity message', () {
      reporter.warning(
        filePath: 'lib/b.dart',
        line: 20,
        column: 0,
        message: 'Non-fatal issue.',
        suggestion: 'Consider fixing.',
      );

      expect(reporter.messages, hasLength(1));
      expect(reporter.messages.first.severity, DiagnosticSeverity.warning);
    });

    test('hasErrors is false when only warnings exist', () {
      reporter
        ..warning(filePath: 'lib/c.dart', line: 1, column: 0, message: 'warn', suggestion: 'suggest')
        ..warning(filePath: 'lib/d.dart', line: 2, column: 0, message: 'warn2', suggestion: 'suggest2');

      expect(reporter.hasErrors, isFalse);
    });

    test('hasErrors is true when at least one error exists', () {
      reporter
        ..warning(filePath: 'lib/a.dart', line: 1, column: 0, message: 'warn', suggestion: 's')
        ..error(filePath: 'lib/b.dart', line: 2, column: 0, message: 'err', suggestion: 's');

      expect(reporter.hasErrors, isTrue);
    });

    test('messages returns all collected diagnostics in order', () {
      reporter
        ..error(filePath: 'lib/first.dart', line: 1, column: 0, message: 'first', suggestion: 's1')
        ..warning(filePath: 'lib/second.dart', line: 2, column: 0, message: 'second', suggestion: 's2')
        ..error(filePath: 'lib/third.dart', line: 3, column: 0, message: 'third', suggestion: 's3');

      expect(reporter.messages, hasLength(3));
      expect(reporter.messages[0].message, 'first');
      expect(reporter.messages[1].message, 'second');
      expect(reporter.messages[2].message, 'third');
    });

    test('messages returns unmodifiable list', () {
      reporter.error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'msg', suggestion: 's');

      expect(
        () => reporter.messages.add(
          const DiagnosticMessage(
            severity: DiagnosticSeverity.error,
            filePath: 'x',
            line: 0,
            column: 0,
            message: 'x',
            suggestion: 'x',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('multiple calls accumulate diagnostics', () {
      for (var i = 0; i < 5; i++) {
        reporter.error(filePath: 'lib/$i.dart', line: i, column: 0, message: 'error $i', suggestion: 'fix $i');
      }
      expect(reporter.messages, hasLength(5));
    });

    group('errorCount and warningCount', () {
      test('errorCount returns 0 when empty', () {
        expect(reporter.errorCount, 0);
      });

      test('warningCount returns 0 when empty', () {
        expect(reporter.warningCount, 0);
      });

      test('errorCount returns correct count with mixed diagnostics', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'err1', suggestion: 's')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'warn1', suggestion: 's')
          ..error(filePath: 'lib/c.dart', line: 3, column: 0, message: 'err2', suggestion: 's');

        expect(reporter.errorCount, 2);
      });

      test('warningCount returns 0 when only errors exist', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'err1', suggestion: 's')
          ..error(filePath: 'lib/b.dart', line: 2, column: 0, message: 'err2', suggestion: 's');

        expect(reporter.warningCount, 0);
      });

      test('warningCount returns correct count with mixed diagnostics', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'err', suggestion: 's')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'warn1', suggestion: 's')
          ..warning(filePath: 'lib/c.dart', line: 3, column: 0, message: 'warn2', suggestion: 's')
          ..warning(filePath: 'lib/d.dart', line: 4, column: 0, message: 'warn3', suggestion: 's');

        expect(reporter.warningCount, 3);
      });
    });

    group('flushToLog', () {
      late Logger logger;
      late List<LogRecord> records;
      late StreamSubscription<LogRecord> subscription;

      setUp(() {
        logger = Logger('test.flushToLog');
        records = [];
        logger.level = Level.ALL;
        subscription = logger.onRecord.listen(records.add);
      });

      tearDown(() async {
        await subscription.cancel();
      });

      test('returns true when no diagnostics collected', () {
        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isTrue);
      });

      test('logs nothing when no diagnostics collected', () {
        reporter.flushToLog(logger);

        expect(records, isEmpty);
      });

      test('returns true when only warnings exist', () {
        reporter
          ..warning(filePath: 'lib/a.dart', line: 1, column: 0, message: 'warn1', suggestion: 's')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'warn2', suggestion: 's');

        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isTrue);
      });

      test('returns false when at least one error exists', () {
        reporter
          ..warning(filePath: 'lib/a.dart', line: 1, column: 0, message: 'warn', suggestion: 's')
          ..error(filePath: 'lib/b.dart', line: 2, column: 0, message: 'err', suggestion: 's');

        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isFalse);
      });

      test('emits individual diagnostics to logger with correct levels', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'an error', suggestion: 'fix error')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'a warning', suggestion: 'fix warning')
          ..flushToLog(logger);

        // 2 individual diagnostics + 1 summary = 3 records
        expect(records, hasLength(3));
        expect(records[0].level, Level.SEVERE);
        expect(records[0].message, contains('an error'));
        expect(records[1].level, Level.WARNING);
        expect(records[1].message, contains('a warning'));
      });

      test('emits summary line at Level.INFO', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'err', suggestion: 's')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'warn', suggestion: 's')
          ..flushToLog(logger);

        final LogRecord summaryRecord = records.last;
        expect(summaryRecord.level, Level.INFO);
        expect(summaryRecord.message, '[inject_generator] Build failed with 1 error(s) and 1 warning(s).');
      });

      test('summary shows correct counts for multiple diagnostics', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'err1', suggestion: 's')
          ..error(filePath: 'lib/b.dart', line: 2, column: 0, message: 'err2', suggestion: 's')
          ..error(filePath: 'lib/c.dart', line: 3, column: 0, message: 'err3', suggestion: 's')
          ..warning(filePath: 'lib/d.dart', line: 4, column: 0, message: 'warn1', suggestion: 's')
          ..warning(filePath: 'lib/e.dart', line: 5, column: 0, message: 'warn2', suggestion: 's')
          ..flushToLog(logger);

        final LogRecord summaryRecord = records.last;
        expect(summaryRecord.message, '[inject_generator] Build failed with 3 error(s) and 2 warning(s).');
      });

      test('warnings-only summary shows 0 error(s)', () {
        reporter
          ..warning(filePath: 'lib/a.dart', line: 1, column: 0, message: 'warn', suggestion: 's')
          ..flushToLog(logger);

        final LogRecord summaryRecord = records.last;
        expect(summaryRecord.message, '[inject_generator] Build completed with 0 error(s) and 1 warning(s).');
      });

      // Documents known behavior: flushToLog re-emits on every call.
      // Architecture guarantees a fresh DiagnosticReporter per build,
      // so double-flush never occurs in production.
      test('calling flushToLog twice emits all diagnostics and summary twice', () {
        reporter.error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'an error', suggestion: 'fix it');

        reporter.flushToLog(logger);
        reporter.flushToLog(logger);

        // Each call emits 1 diagnostic + 1 summary = 2 records per call = 4 total
        expect(records, hasLength(4));

        // First call: diagnostic + summary
        expect(records[0].level, Level.SEVERE);
        expect(records[0].message, contains('an error'));
        expect(records[1].level, Level.INFO);
        expect(records[1].message, '[inject_generator] Build failed with 1 error(s) and 0 warning(s).');

        // Second call: same diagnostic + same summary again
        expect(records[2].level, Level.SEVERE);
        expect(records[2].message, contains('an error'));
        expect(records[3].level, Level.INFO);
        expect(records[3].message, '[inject_generator] Build failed with 1 error(s) and 0 warning(s).');
      });
    });

    group('reportToLog', () {
      late Logger logger;
      late List<LogRecord> records;
      late StreamSubscription<LogRecord> subscription;

      setUp(() {
        logger = Logger('test.inject_generator');
        records = [];
        logger.level = Level.ALL;
        subscription = logger.onRecord.listen(records.add);
      });

      tearDown(() async {
        await subscription.cancel();
      });

      test('errors produce Level.SEVERE records', () {
        reporter
          ..error(
            filePath: 'lib/a.dart',
            line: 1,
            column: 0,
            message: 'An error occurred.',
            suggestion: 'Fix the error.',
          )
          ..reportToLog(logger);

        expect(records, hasLength(1));
        expect(records.first.level, Level.SEVERE);
      });

      test('warnings produce Level.WARNING records', () {
        reporter
          ..warning(
            filePath: 'lib/b.dart',
            line: 2,
            column: 0,
            message: 'A warning occurred.',
            suggestion: 'Consider fixing.',
          )
          ..reportToLog(logger);

        expect(records, hasLength(1));
        expect(records.first.level, Level.WARNING);
      });

      test('[inject_generator] prefix is present in every logged message', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'err', suggestion: 'fix')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'warn', suggestion: 'fix')
          ..reportToLog(logger);

        expect(records, hasLength(2));
        for (final record in records) {
          expect(record.message, startsWith('[inject_generator]'));
        }
      });

      test('reports errors and warnings in order', () {
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'first error', suggestion: 's')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'second warning', suggestion: 's')
          ..reportToLog(logger);

        expect(records, hasLength(2));
        expect(records[0].level, Level.SEVERE);
        expect(records[0].message, contains('first error'));
        expect(records[1].level, Level.WARNING);
        expect(records[1].message, contains('second warning'));
      });
    });

    group('multi-phase aggregation', () {
      test('collects diagnostics from simulated analysis and validation phases', () {
        // Simulated analysis phase
        reporter
          ..error(
            filePath: 'lib/src/analysis/component.dart',
            line: 15,
            column: 0,
            message: 'Missing binding: AuthService is required by AppComponent.',
            suggestion: 'Add @provides AuthService to your AuthModule.',
          )
          // Simulated validation phase
          ..warning(
            filePath: 'lib/src/service.dart',
            line: 5,
            column: 0,
            message: "Class 'LogService' has no @inject annotation.",
            suggestion: 'Add @inject to make this explicit.',
          );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages, hasLength(2));
        expect(reporter.messages[0].severity, DiagnosticSeverity.error);
        expect(reporter.messages[1].severity, DiagnosticSeverity.warning);
      });

      test('reportToLog outputs all phases to logger', () {
        final logger = Logger('test.multi_phase');
        final records = <LogRecord>[];
        logger.level = Level.ALL;
        logger.onRecord.listen(records.add);

        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'analysis error', suggestion: 'fix')
          ..warning(filePath: 'lib/b.dart', line: 2, column: 0, message: 'validation warning', suggestion: 'fix')
          ..reportToLog(logger);

        expect(records, hasLength(2));
        expect(records[0].level, Level.SEVERE);
        expect(records[1].level, Level.WARNING);
      });

      test('three-phase pipeline preserves all diagnostics in order via flushToLog', () {
        final logger = Logger('test.three_phase');
        final records = <LogRecord>[];
        logger.level = Level.ALL;
        logger.onRecord.listen(records.add);

        // Phase 1: Analysis
        reporter
          ..error(
            filePath: 'lib/src/analysis/component.dart',
            line: 10,
            column: 0,
            message: 'Missing binding: AuthService.',
            suggestion: 'Add @provides AuthService.',
          )
          // Phase 2: Validation
          ..warning(
            filePath: 'lib/src/service.dart',
            line: 5,
            column: 0,
            message: "Unannotated class 'LogService'.",
            suggestion: 'Add @inject.',
          )
          ..error(
            filePath: 'lib/src/graph.dart',
            line: 20,
            column: 0,
            message: 'Cycle detected: A -> B -> A.',
            suggestion: 'Break the cycle.',
          )
          // Phase 3: Codegen (would be skipped in real pipeline due to errors)
          ..warning(
            filePath: 'lib/src/codegen/output.dart',
            line: 1,
            column: 0,
            message: 'Unused binding: FooService.',
            suggestion: 'Remove the unused binding.',
          );

        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isFalse);
        expect(reporter.messages, hasLength(4));
        expect(reporter.messages[0].message, 'Missing binding: AuthService.');
        expect(reporter.messages[1].message, "Unannotated class 'LogService'.");
        expect(reporter.messages[2].message, 'Cycle detected: A -> B -> A.');
        expect(reporter.messages[3].message, 'Unused binding: FooService.');

        // 4 individual diagnostics + 1 summary = 5 records
        expect(records, hasLength(5));
        expect(records[0].level, Level.SEVERE);
        expect(records[1].level, Level.WARNING);
        expect(records[2].level, Level.SEVERE);
        expect(records[3].level, Level.WARNING);
        expect(records[4].level, Level.INFO);
        expect(records[4].message, '[inject_generator] Build failed with 2 error(s) and 2 warning(s).');
      });

      test('multiple errors from different phases blocks generation', () {
        final logger = Logger('test.multi_errors');
        final records = <LogRecord>[];
        logger.level = Level.ALL;
        logger.onRecord.listen(records.add);

        // Analysis phase errors
        reporter
          ..error(filePath: 'lib/a.dart', line: 1, column: 0, message: 'analysis error 1', suggestion: 'fix 1')
          ..error(filePath: 'lib/b.dart', line: 2, column: 0, message: 'analysis error 2', suggestion: 'fix 2')
          // Validation phase errors
          ..error(filePath: 'lib/c.dart', line: 3, column: 0, message: 'validation error', suggestion: 'fix 3');

        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isFalse);
        expect(reporter.errorCount, 3);
        expect(reporter.warningCount, 0);

        // All 3 errors visible in log + 1 summary
        final List<LogRecord> severeRecords = records.where((r) => r.level == Level.SEVERE).toList();
        expect(severeRecords, hasLength(3));
        expect(records.last.message, '[inject_generator] Build failed with 3 error(s) and 0 warning(s).');
      });

      test('warnings-only across phases allows generation to proceed', () {
        final logger = Logger('test.warnings_only');
        final records = <LogRecord>[];
        logger.level = Level.ALL;
        logger.onRecord.listen(records.add);

        // Analysis phase warning + Validation phase warning
        reporter
          ..warning(filePath: 'lib/a.dart', line: 1, column: 0, message: 'analysis warning', suggestion: 'consider fix')
          ..warning(
            filePath: 'lib/b.dart',
            line: 2,
            column: 0,
            message: 'validation warning',
            suggestion: 'consider fix',
          );

        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isTrue);
        expect(reporter.errorCount, 0);
        expect(reporter.warningCount, 2);

        // All warnings visible
        final List<LogRecord> warningRecords = records.where((r) => r.level == Level.WARNING).toList();
        expect(warningRecords, hasLength(2));
        expect(records.last.message, '[inject_generator] Build completed with 0 error(s) and 2 warning(s).');
      });

      test('mixed errors and warnings keeps all warnings visible alongside errors', () {
        final logger = Logger('test.mixed');
        final records = <LogRecord>[];
        logger.level = Level.ALL;
        logger.onRecord.listen(records.add);

        reporter
          ..warning(filePath: 'lib/a.dart', line: 1, column: 0, message: 'warning before error', suggestion: 's')
          ..error(filePath: 'lib/b.dart', line: 2, column: 0, message: 'fatal error', suggestion: 's')
          ..warning(filePath: 'lib/c.dart', line: 3, column: 0, message: 'warning after error', suggestion: 's');

        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isFalse);
        expect(reporter.errorCount, 1);
        expect(reporter.warningCount, 2);

        // All 3 diagnostics + 1 summary = 4 records
        expect(records, hasLength(4));

        // Both warnings visible in log records
        final List<LogRecord> warningRecords = records.where((r) => r.level == Level.WARNING).toList();
        expect(warningRecords, hasLength(2));
        expect(warningRecords[0].message, contains('warning before error'));
        expect(warningRecords[1].message, contains('warning after error'));

        // Error visible
        final List<LogRecord> severeRecords = records.where((r) => r.level == Level.SEVERE).toList();
        expect(severeRecords, hasLength(1));
        expect(severeRecords[0].message, contains('fatal error'));

        // Summary shows both counts
        expect(records.last.message, '[inject_generator] Build failed with 1 error(s) and 2 warning(s).');
      });

      test('empty reporter has zero overhead via flushToLog', () {
        final logger = Logger('test.empty');
        final records = <LogRecord>[];
        logger.level = Level.ALL;
        logger.onRecord.listen(records.add);

        final bool canProceed = reporter.flushToLog(logger);

        expect(canProceed, isTrue);
        expect(records, isEmpty);
        expect(reporter.errorCount, 0);
        expect(reporter.warningCount, 0);
        expect(reporter.messages, isEmpty);
      });
    });
  });

  group('DiagnosticReporterExt', () {
    late DiagnosticReporter reporter;

    setUp(() {
      reporter = DiagnosticReporter();
    });

    test('errorForElement creates error with snippet from real Element', () async {
      final LibraryElement library = await _resolveLibrary('''
class MyService {}
''');
      final ClassElement element = library.getClass('MyService')!;

      reporter.errorForElement(element, message: 'Bad class.', suggestion: 'Fix it.');

      expect(reporter.messages, hasLength(1));
      final DiagnosticMessage msg = reporter.messages.first;
      expect(msg.severity, DiagnosticSeverity.error);
      expect(msg.message, 'Bad class.');
      expect(msg.suggestion, 'Fix it.');
      expect(msg.snippet, isNotNull);
      expect(msg.snippet!.lines, isNotEmpty);
    });

    test('warningForElement creates warning with snippet from real Element', () async {
      final LibraryElement library = await _resolveLibrary('''
class MyService {}
''');
      final ClassElement element = library.getClass('MyService')!;

      reporter.warningForElement(element, message: 'Consider renaming.');

      expect(reporter.messages, hasLength(1));
      final DiagnosticMessage msg = reporter.messages.first;
      expect(msg.severity, DiagnosticSeverity.warning);
      expect(msg.message, 'Consider renaming.');
      expect(msg.suggestion, isNull);
      expect(msg.snippet, isNotNull);
    });

    test('infoForElement creates info with snippet from real Element', () async {
      final LibraryElement library = await _resolveLibrary('''
class MyService {}
''');
      final ClassElement element = library.getClass('MyService')!;

      reporter.infoForElement(element, message: 'Note this.', suggestion: 'See docs.');

      expect(reporter.messages, hasLength(1));
      final DiagnosticMessage msg = reporter.messages.first;
      expect(msg.severity, DiagnosticSeverity.info);
      expect(msg.message, 'Note this.');
      expect(msg.suggestion, 'See docs.');
      expect(msg.snippet, isNotNull);
    });

    test('errorForElement sets correct file path and line info', () async {
      final LibraryElement library = await _resolveLibrary('''
class MyService {}
''');
      final ClassElement element = library.getClass('MyService')!;

      reporter.errorForElement(element, message: 'msg');

      final DiagnosticMessage msg = reporter.messages.first;
      expect(msg.filePath, isNotEmpty);
      expect(msg.line, greaterThan(0));
    });
  });
}
