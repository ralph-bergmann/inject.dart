import 'package:build/build.dart';
import 'package:inject_generator/src/builder/factory_builder_options.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('FactoryBuilderOptions', () {
    group('fromBuilderOptions', () {
      test('returns defaults silently when config is empty', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        final opts = FactoryBuilderOptions.fromBuilderOptions(BuilderOptions.empty, log: logger);

        expect(opts, isA<FactoryBuilderOptions>());
        expect(logs, isEmpty, reason: 'empty config must not log');
      });

      test('warns about any provided key (factory_builder accepts no options)', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        FactoryBuilderOptions.fromBuilderOptions(
          BuilderOptions({'nullable_duplicate_binding_policy': 'warn'}),
          log: logger,
        );

        final warnings = logs.where((r) => r.level == Level.WARNING).map((r) => r.message).toList();
        expect(warnings, hasLength(1));
        expect(warnings.single, contains('nullable_duplicate_binding_policy'));
        expect(warnings.single, contains('factory_builder'));
        expect(warnings.single, contains('inject_builder'));
      });

      test('aggregates multiple unknown keys into one WARNING', () {
        final logs = <LogRecord>[];
        final logger = Logger('test')..onRecord.listen(logs.add);

        FactoryBuilderOptions.fromBuilderOptions(
          BuilderOptions({'a': 1, 'b': 2, 'c': 3}),
          log: logger,
        );

        final warnings = logs.where((r) => r.level == Level.WARNING).map((r) => r.message).toList();
        expect(warnings, hasLength(1));
        expect(warnings.single, allOf(contains("'a'"), contains("'b'"), contains("'c'")));
      });
    });

    group('defaults', () {
      test('exists as a const instance', () {
        expect(FactoryBuilderOptions.defaults, isA<FactoryBuilderOptions>());
      });
    });
  });
}
