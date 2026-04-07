import 'package:build/build.dart';
import 'package:inject_generator/src/builder/inject_builder_options.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('InjectBuilderOptions', () {
    group('fromBuilderOptions', () {
      test('returns defaults when config is empty', () {
        final opts = InjectBuilderOptions.fromBuilderOptions(BuilderOptions.empty);
        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.error);
      });

      test("parses 'error' correctly", () {
        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 'error'}),
        );
        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.error);
      });

      test("parses 'warn' correctly", () {
        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 'warn'}),
        );
        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.warn);
      });

      test("parses 'allow' correctly", () {
        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 'allow'}),
        );
        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.allow);
      });

      test('logs SEVERE for invalid enum string and mentions case-sensitivity', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 'invalid_value'}),
          log: logger,
        );

        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.error);
        final severe = logs.where((r) => r.level == Level.SEVERE).map((r) => r.message).toList();
        expect(severe, isNotEmpty);
        expect(severe.first, contains('invalid_value'));
        expect(severe.first, contains("'error', 'warn', 'allow'"));
        expect(severe.first, contains('case-sensitive'));
      });

      test('logs SEVERE for case-mismatch (Allow/WARN/Error)', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 'Allow'}),
          log: logger,
        );

        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.error);
        final severe = logs.where((r) => r.level == Level.SEVERE).map((r) => r.message).toList();
        expect(severe, isNotEmpty);
        expect(severe.first, contains('Allow'));
      });

      test('logs SEVERE for wrong type (int instead of string) and falls back to error', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 42}),
          log: logger,
        );

        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.error);
        final severe = logs.where((r) => r.level == Level.SEVERE).map((r) => r.message).toList();
        expect(severe, isNotEmpty);
        expect(severe.first, contains('must be a string'));
        expect(severe.first, contains('int'));
      });

      test('logs SEVERE for null value with "no value" message', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': null}),
          log: logger,
        );

        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.error);
        final severe = logs.where((r) => r.level == Level.SEVERE).map((r) => r.message).toList();
        expect(severe, isNotEmpty);
        expect(severe.first, contains('no value'));
        expect(severe.first, isNot(contains('Null')));
      });

      test('logs WARNING for unknown top-level key', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        InjectBuilderOptions.fromBuilderOptions(BuilderOptions({'unknown_option': 'value'}), log: logger);

        final warnings = logs.where((r) => r.level == Level.WARNING).map((r) => r.message).toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first, contains('unknown_option'));
        expect(warnings.first, contains('nullable_duplicate_binding_policy'));
      });

      test('aggregates multiple unknown keys into a single WARNING', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'first_unknown': 1, 'second_unknown': 2, 'third_unknown': 3}),
          log: logger,
        );

        final warnings = logs.where((r) => r.level == Level.WARNING).map((r) => r.message).toList();
        expect(warnings, hasLength(1), reason: 'multiple unknown keys must be aggregated');
        expect(warnings.single, contains('first_unknown'));
        expect(warnings.single, contains('second_unknown'));
        expect(warnings.single, contains('third_unknown'));
      });

      test('logs WARNING for unknown key even when valid key is also present', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 'allow', 'extra_key': true}),
          log: logger,
        );

        expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.allow);
        final warnings = logs.where((r) => r.level == Level.WARNING).map((r) => r.message).toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first, contains('extra_key'));
      });
    });

    group('debug_graph', () {
      test('parses debug_graph: true', () {
        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'debug_graph': true}),
        );
        expect(opts.debugGraph, isTrue);
      });

      test('parses debug_graph: false', () {
        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'debug_graph': false}),
        );
        expect(opts.debugGraph, isFalse);
      });

      test('defaults debug_graph to false when absent', () {
        expect(InjectBuilderOptions.defaults.debugGraph, isFalse);
      });

      test('logs SEVERE for non-bool debug_graph value and falls back to false', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'debug_graph': 'yes'}),
          log: logger,
        );

        expect(opts.debugGraph, isFalse);
        final severe = logs.where((r) => r.level == Level.SEVERE).map((r) => r.message).toList();
        expect(severe, isNotEmpty);
        expect(severe.first, contains('must be a bool'));
        expect(severe.first, contains('String'));
      });

      test('logs SEVERE for null debug_graph value and falls back to false', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = InjectBuilderOptions.fromBuilderOptions(
          BuilderOptions({'debug_graph': null}),
          log: logger,
        );

        expect(opts.debugGraph, isFalse);
        final severe = logs.where((r) => r.level == Level.SEVERE).map((r) => r.message).toList();
        expect(severe, isNotEmpty);
        expect(severe.first, contains('no value'));
      });

      test(
        'aggregates all known keys (debug_graph, nullable_duplicate_binding_policy) — unknown-key warning only for unknown keys',
        () {
          final logs = <LogRecord>[];
          final logger = Logger('test')..onRecord.listen(logs.add);

          final opts = InjectBuilderOptions.fromBuilderOptions(
            BuilderOptions({
              'debug_graph': true,
              'nullable_duplicate_binding_policy': 'allow',
              'totally_unknown_key': 'oops',
            }),
            log: logger,
          );

          expect(opts.debugGraph, isTrue);
          expect(opts.nullableDuplicatePolicy, NullableDuplicatePolicy.allow);

          final warnings = logs.where((r) => r.level == Level.WARNING).map((r) => r.message).toList();
          expect(warnings, hasLength(1), reason: 'only one aggregated warning for unknown keys');
          expect(warnings.single, contains('totally_unknown_key'));
          // Both known keys appear in the "Valid options:" section, not the unknown-key list.
          expect(warnings.single, contains('debug_graph'));
          expect(warnings.single, contains('nullable_duplicate_binding_policy'));
        },
      );
    });

    group('defaults', () {
      test('is a const InjectBuilderOptions with error policy', () {
        expect(InjectBuilderOptions.defaults.nullableDuplicatePolicy, NullableDuplicatePolicy.error);
      });
    });
  });
}
