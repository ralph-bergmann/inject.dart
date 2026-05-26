import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/codegen/provider_generator.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:test/test.dart';

import '../helpers/pipeline_golden_helper.dart';

const _goldenDir = 'test/golden/provider_generator';

void main() {
  group('ProviderGenerator', () {
    late DiagnosticReporter reporter;
    late AnnotationReader reader;
    late ProviderGenerator generator;

    setUp(() {
      reporter = DiagnosticReporter();
      reader = AnnotationReader(reporter: reporter);
      generator = ProviderGenerator();
    });

    group('providerClassName / providerBaseName', () {
      test('Pascal-cases primitive type names to avoid field/class collision', () {
        // Without Pascal-casing, both class and field would be `_int\$Provider`,
        // producing invalid Dart: `late final _int\$Provider _int\$Provider;`.
        expect(ProviderGenerator.providerClassName('int', null), r'_Int$Provider');
        expect(ProviderGenerator.providerBaseName('int', null), r'int$Provider');
        expect(ProviderGenerator.providerClassName('double', null), r'_Double$Provider');
        expect(ProviderGenerator.providerBaseName('double', null), r'double$Provider');
        expect(ProviderGenerator.providerClassName('bool', null), r'_Bool$Provider');
        expect(ProviderGenerator.providerBaseName('bool', null), r'bool$Provider');
      });

      test('preserves PascalCase for normal class names', () {
        expect(ProviderGenerator.providerClassName('MyService', null), r'_MyService$Provider');
        expect(ProviderGenerator.providerBaseName('MyService', null), r'myService$Provider');
      });

      test('class identifier always differs from field base for any input', () {
        for (final name in ['int', 'double', 'bool', 'num', 'Object', 'Function', 'MyClass']) {
          final cls = ProviderGenerator.providerClassName(name, null);
          final base = ProviderGenerator.providerBaseName(name, null);
          // Strip leading '_' from class for the comparison (field name has '_' prefix
          // applied by _providerFieldName; base is the suffix-only form).
          expect(
            cls.substring(1),
            isNot(equals(base)),
            reason: 'Class identifier "$cls" must differ from field base "$base" for "$name"',
          );
        }
      });
    });

    test(
      'module_provider_async_non_singleton golden',
      () => runPipelineGolden(
        fixtureName: 'async_module',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'inject_provider_multi_deps golden',
      () => runPipelineGolden(
        fixtureName: 'inject_multi_deps',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'inject_provider_named_params golden',
      () => runPipelineGolden(
        fixtureName: 'inject_named_params',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'inject_provider_named_constructor golden',
      () => runPipelineGolden(
        fixtureName: 'inject_named_constructor',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'inject_provider_factory_constructor golden',
      () => runPipelineGolden(
        fixtureName: 'inject_factory_constructor',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'inject_provider_constructor_param golden',
      // A regular @inject class can receive a Provider<T> as a constructor
      // parameter (not only as a component entry point). The generator must
      // pass the provider directly; runAnalyzer verifies the emitted code is
      // type-correct (a resolved T instead of Provider<T> would not compile).
      () => runPipelineGolden(
        fixtureName: 'inject_provider_constructor_param',
        goldenDir: _goldenDir,
      ),
    );
  });
}
