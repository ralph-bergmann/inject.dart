import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:code_builder/src/specs/class.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/component_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/codegen/component_generator.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/graph_validator.dart';
import 'package:test/test.dart';

import '../helpers/golden_helper.dart';
import '../helpers/pipeline_golden_helper.dart';

const _ownedDir = 'test/golden/component_generator';
const _sharedDir = 'test/golden/shared';
const _sourceUri = 'package:_resolve_source/_resolve_source.dart';

void main() {
  group('ComponentGenerator goldens', () {
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

    test('method_entry_point_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'method_entry_point_component',
        goldenDir: _ownedDir,
      );
    });

    test('minimal_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'minimal_component',
        goldenDir: _sharedDir,
      );
    });

    test('inject_constructor_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'inject_constructor_component',
        goldenDir: _sharedDir,
      );
    });

    test('singleton_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'singleton_component',
        goldenDir: _ownedDir,
      );
    });

    test('async_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'async_component',
        goldenDir: _ownedDir,
      );
    });

    test('interface_entry_point_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'interface_entry_point_component',
        goldenDir: _ownedDir,
      );
    });

    test('multi_entry_point_same_type_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'multi_entry_point_same_type_component',
        goldenDir: _ownedDir,
      );
    });

    test('qualified_entry_point_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'qualified_entry_point_component',
        goldenDir: _ownedDir,
      );
    });

    // This fixture intentionally provides both `String` and `String?` from
    // the same module (testing separate nullable/non-nullable providers).
    // Setting allow policy so the duplicate-binding guard does not fire.
    test('nullable_entry_point_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'nullable_entry_point_component',
        goldenDir: _ownedDir,
        injectBuilderOptions: BuilderOptions({'nullable_duplicate_binding_policy': 'allow'}),
      );
    });

    test('provider_entry_point_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'provider_entry_point_component',
        goldenDir: _ownedDir,
      );
    });

    test('provider_future_entry_point_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'provider_future_entry_point_component',
        goldenDir: _ownedDir,
      );
    });
  });

  group('ComponentGenerator behavior', () {
    late DiagnosticReporter reporter;
    late AnnotationReader reader;
    late ComponentGenerator generator;

    setUp(() {
      reporter = DiagnosticReporter();
      reader = AnnotationReader(reporter: reporter);
      generator = ComponentGenerator();
    });

    test('same_name_different_qualifier_entry_points diagnostic', () async {
      final LibraryElement library = await resolveFixture(
        '$_ownedDir/same_name_different_qualifier_entry_points.dart',
      );
      final ClassElement componentClass = library.getClass('CarComponent')!;
      final ComponentData componentData = reader.readComponent(componentClass)!;

      GraphValidator(reporter: reporter).validate(
        sourceLibrary: library,
        componentClass: componentClass,
        componentData: componentData,
        modules: [],
        injectables: [],
      );

      expect(reporter.hasErrors, isTrue);
      expect(reporter.errorCount, equals(1));
      expect(reporter.messages.first.message, contains("Entry point 'label'"));
      expect(reporter.messages.first.message, contains('conflicting qualifiers'));
      expect(reporter.messages.first.message, contains('#brand'));
      expect(reporter.messages.first.message, contains('#model'));
    });

    test('deterministic output across runs', () async {
      final LibraryElement library = await resolveFixture('$_sharedDir/single_module_component.dart');
      final ClassElement componentClass = library.getClass('MyComponent')!;
      final ComponentData componentData = reader.readComponent(componentClass)!;
      final ClassElement moduleClass = library.getClass('MyModule')!;
      final ModuleData moduleData = reader.readModule(moduleClass);

      final String output1 = emitClass(
        generator.generate(
          sourceUri: _sourceUri,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        ),
      );

      final String output2 = emitClass(
        generator.generate(
          sourceUri: _sourceUri,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        ),
      );

      expect(output1, equals(output2));
    });

    test('listener provider is instantiated in constructor but not entry-point', () async {
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

      final ClassElement componentClass = library.getClass('AppComponent')!;
      final ComponentData componentData = reader.readComponent(componentClass)!;
      final ClassElement moduleClass = library.getClass('AppModule')!;
      final ModuleData moduleData = reader.readModule(moduleClass);
      final ProviderDescriptor listenerProvider = moduleData.providers.firstWhere(
        (p) => p.metadata.isProvisionListener,
      );

      final Class classSpec = generator.generate(
        sourceUri: _sourceUri,
        componentClass: componentClass,
        componentData: componentData,
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
        listenerProviders: [(moduleClass: moduleClass, descriptor: listenerProvider)],
      );

      final String output = emitClass(classSpec);

      // Listener provider is instantiated in the constructor
      expect(output, contains('_ProvisionListenerOfObject\$Provider'));
      // But has no getter (not an entry point)
      expect(output, isNot(contains('ProvisionListener<Object> get')));
      // The entry point is just Heater
      expect(output, contains('Heater get heater'));
    });
  });
}
