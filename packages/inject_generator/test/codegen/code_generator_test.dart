import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/codegen/code_generator.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:test/test.dart';

import '../helpers/golden_helper.dart';
import '../helpers/pipeline_golden_helper.dart';

const _ownedDir = 'test/golden/code_generator';
const _sharedDir = 'test/golden/shared';

void main() {
  group('CodeGenerator goldens', () {
    test('minimal_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'minimal_component',
        goldenDir: _sharedDir,
      );
    });

    test('single_module_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'single_module_component',
        goldenDir: _sharedDir,
      );
    });

    test('multi_module_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'multi_module_component',
        goldenDir: _sharedDir,
      );
    });

    test('inject_constructor_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'inject_constructor_component',
        goldenDir: _sharedDir,
      );
    });

    test('sorted_providers_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'sorted_providers_component',
        goldenDir: _ownedDir,
      );
    });

    test('singleton_providers_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'singleton_providers_component',
        goldenDir: _ownedDir,
      );
    });

    test('mixed_factory_inject_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'mixed_factory_inject_component',
        goldenDir: _ownedDir,
      );
    });

    test('entry_point_as_factory_dep_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'entry_point_as_factory_dep_component',
        goldenDir: _ownedDir,
      );
    });

    test('typedef_module_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'typedef_module_component',
        goldenDir: _ownedDir,
      );
    });

    test('async_dep_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'async_dep_component',
        goldenDir: _ownedDir,
      );
    });

    test('multi_constructor_qualifier_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'multi_constructor_qualifier_component',
        goldenDir: _ownedDir,
      );
    });

    test('mixed_inject_assisted_same_class_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'mixed_inject_assisted_same_class_component',
        goldenDir: _ownedDir,
      );
    });

    test('listener_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'listener_component',
        goldenDir: _ownedDir,
      );
    });
  });

  group('CodeGenerator behavior', () {
    late DiagnosticReporter reporter;
    late AnnotationReader reader;
    late CodeGenerator generator;

    setUp(() {
      reporter = DiagnosticReporter();
      reader = AnnotationReader(reporter: reporter);
      generator = CodeGenerator();
    });

    test('deterministic output across runs', () async {
      final LibraryElement library = await resolveFixture('$_sharedDir/single_module_component.dart');

      final String? output1 = generator.generate(library: library, reader: reader);
      final String? output2 = generator.generate(library: library, reader: reader);

      expect(output1, equals(output2));
    });

    test('returns null when no component found', () async {
      final LibraryElement library = await resolveFixture('$_ownedDir/simple_module.dart');
      final String? output = generator.generate(library: library, reader: reader);
      expect(output, isNull);
    });

    test('partitions @provisionListener providers from regular providers', () async {
      final LibraryElement library = await resolveSource(
        '''
        import 'package:inject_annotation/inject_annotation.dart';

        class Heater {}

        class LoggingListener implements ProvisionListener<Object> {
          @override
          void onProvision(Object instance) {}
        }

        @module
        class AppModule {
          @provides
          Heater provideHeater() => Heater();

          @provides
          @singleton
          @provisionListener
          ProvisionListener<Object> provideListener() => LoggingListener();
        }

        @Component([AppModule])
        abstract class AppComponent {
          @inject
          Heater get heater;
        }
        ''',
        (resolver) async => resolver.libraryFor(
          AssetId('_resolve_source', 'lib/_resolve_source.dart'),
        ),
        readAllSourcesFromFilesystem: true,
      );

      final String? output = generator.generate(library: library, reader: reader);

      expect(output, isNotNull);
      // Both providers should be generated (listener is still a regular provider)
      expect(output, contains('_Heater\$Provider'));
      expect(output, contains('_ProvisionListenerOfObject\$Provider'));
    });
  });
}
