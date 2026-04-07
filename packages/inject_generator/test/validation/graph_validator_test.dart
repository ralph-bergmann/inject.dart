import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/component_reader.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:inject_generator/src/validation/graph_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late GraphValidator validator;

  setUp(() {
    reporter = DiagnosticReporter();
    validator = GraphValidator(reporter: reporter);
  });

  group('GraphValidator', () {
    group('validate', () {
      test('delegates to sub-validators when graph is valid', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class CoffeeModule {
            @provides
            String provideName() => 'coffee';
          }

          @inject
          class CoffeeMaker {
            final String name;
            CoffeeMaker(this.name);
          }

          @Component([CoffeeModule])
          abstract class CoffeeShop {
            @inject
            CoffeeMaker get maker;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CoffeeShop')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        final ClassElement moduleClass = library.getClass('CoffeeModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        final ClassElement injectableClass = library.getClass('CoffeeMaker')!;
        final InjectableData injectable = reader.readInjectable(injectableClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [(classElement: injectableClass, injectable: injectable)],
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('collects all errors without stopping early', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class _PrivateService {}

          class _AnotherPrivate {}

          @component
          abstract class CoffeeShop {
            @inject
            _PrivateService get service;
            @inject
            _AnotherPrivate get another;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CoffeeShop')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [],
          injectables: [],
        );

        // Both private types should be reported — not just the first one.
        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, greaterThanOrEqualTo(2));
      });

      test('reports error for private provider method in inject output', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class CoffeeModule {
            @provides
            String _provideName() => 'coffee';
          }

          @Component([CoffeeModule])
          abstract class CoffeeShop {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CoffeeShop')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('CoffeeModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('Private method'));
      });

      test('reports error for private generic type argument in inject output', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class _PrivateService {}

          @component
          abstract class CoffeeShop {
            @inject
            List<_PrivateService> get services;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CoffeeShop')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((message) => message.message.contains('_PrivateService')), isTrue);
      });

      test('allows same-library private symbols for factory output', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class _PrivateService {}

          @component
          abstract class CoffeeShop {
            @inject
            _PrivateService get service;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CoffeeShop')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        final ClassElement injectableClass = library.getClass('_PrivateService')!;
        final InjectableData injectable = reader.readInjectable(injectableClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [],
          injectables: [(classElement: injectableClass, injectable: injectable)],
          outputKind: GeneratedOutputKind.factory,
        );

        expect(reporter.hasErrors, isFalse);
      });

      test('delegates binding validation to BindingResolver', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class MissingService {}

          @module
          class AppModule {
            @provides
            String provideName(MissingService svc) => 'x';
          }

          @Component([AppModule])
          abstract class AppComponent {
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('MissingService')), isTrue);
      });

      test('valid graph passes binding validation without errors', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            int provideCount() => 42;

            @provides
            String provideName(int count) => 'item \$count';
          }

          @Component([AppModule])
          abstract class AppComponent {
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isFalse);
      });

      test('reports cycle error through cycle validation', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideA(int b) => 'a';

            @provides
            int provideB(String a) => 42;
          }

          @Component([AppModule])
          abstract class AppComponent {
            String get a;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('Circular dependency')), isTrue);
      });

      test('acyclic graph passes cycle validation without errors', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class Database {
            Database();
          }

          @inject
          class Repository {
            Repository(Database db);
          }

          @module
          class AppModule {
            @provides
            String provideName(Repository repo) => 'name';
          }

          @Component([AppModule])
          abstract class AppComponent {
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);
        final ClassElement dbClass = library.getClass('Database')!;
        final ClassElement repoClass = library.getClass('Repository')!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [
            (classElement: dbClass, injectable: reader.readInjectable(dbClass)!),
            (classElement: repoClass, injectable: reader.readInjectable(repoClass)!),
          ],
        );

        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors, isEmpty);
      });

      // ── Qualifier Conflict Detection ──────────────────

      test('reports error for duplicate qualified binding via GraphValidator', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const baseUri = Qualifier(#baseUri);

          @module
          class ConfigModule {
            @provides
            @baseUri
            String provideBaseUri() => 'https://example.com';

            @provides
            @baseUri
            String provideUrl() => 'https://other.com';
          }

          @Component([ConfigModule])
          abstract class AppComponent {
            @baseUri
            String get uri;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('ConfigModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> duplicateErrors = reporter.messages.where(
          (m) => m.message.contains('Duplicate binding'),
        );
        expect(duplicateErrors, isNotEmpty);
        expect(duplicateErrors.first.message, contains('#baseUri'));
      });

      test('allows different qualifiers for same type via GraphValidator', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const baseUri = Qualifier(#baseUri);
          const apiKey = Qualifier(#apiKey);

          @module
          class ConfigModule {
            @provides
            @baseUri
            String provideBaseUri() => 'https://example.com';

            @provides
            @apiKey
            String provideApiKey() => 'key-123';
          }

          @Component([ConfigModule])
          abstract class AppComponent {
            @baseUri
            String get uri;

            @apiKey
            String get key;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('ConfigModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        final Iterable<DiagnosticMessage> duplicateErrors = reporter.messages.where(
          (m) => m.message.contains('Duplicate binding'),
        );
        expect(duplicateErrors, isEmpty);
      });

      test('qualifier metadata consistent with asyncBindings after validation', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const label = Qualifier(#label);

          @module
          class AppModule {
            @provides
            @asynchronous
            @label
            String provideLabel() => 'async-label';

            @provides
            int provideCount() => 1;
          }

          @Component([AppModule])
          abstract class AppComponent {
            int get count;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isFalse);

        // Verify qualified binding is tracked in asyncBindings
        final Iterable<MapEntry<BindingKey, bool>> asyncEntries = validator.asyncBindings.entries.where(
          (e) => e.key.qualifier == 'label',
        );
        expect(asyncEntries, isNotEmpty);
        expect(asyncEntries.first.value, isTrue);

        // Verify unqualified binding is not async
        final Iterable<MapEntry<BindingKey, bool>> syncEntries = validator.asyncBindings.entries.where(
          (e) => e.key.qualifier == null && e.key.debugLabel == 'int',
        );
        expect(syncEntries, isNotEmpty);
        expect(syncEntries.first.value, isFalse);
      });

      // ── Reachability Warnings ─────────────────────────

      test('reports warning for unreachable binding via GraphValidator', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideName() => 'used';

            @provides
            int provideUnused() => 42;
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning && m.message.contains('never used'),
        );
        expect(warnings, hasLength(1));
        expect(warnings.first.message, contains('int'));
      });

      test('no warning for fully reachable graph via GraphValidator', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            int provideCount() => 42;

            @provides
            String provideName(int count) => 'item \$count';
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      // ── Provision-Listener Reachability Exemption (Stories 4.4/4.5) ──

      test('typed provisionListener matching provisioned type is exempt from reachability', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Heater {}

          class ElectricHeater implements Heater {
            ElectricHeater();
          }

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            Heater provideHeater() => ElectricHeater();

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Heater> provideListener() => HeaterListener();
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            Heater get heater;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('typed provisionListener not matching any provisioned type triggers reachability warning', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Heater {}

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            String provideName() => 'coffee';

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Heater> provideListener() => HeaterListener();
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning && m.message.contains('never used'),
        );
        expect(warnings, hasLength(1));
        expect(warnings.first.message, contains('ProvisionListener'));
      });

      test('typed provisionListener matching declared but unreachable type triggers reachability warning', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Heater {}

          class ElectricHeater implements Heater {
            ElectricHeater();
          }

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            String provideName() => 'coffee';

            // Heater is declared but NOT reachable from any entry point.
            @provides
            Heater provideHeater() => ElectricHeater();

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Heater> provideListener() => HeaterListener();
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        // Both Heater and the listener should be reported as unreachable.
        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning && m.message.contains('never used'),
        );
        expect(warnings, hasLength(2));
        final List<String> warningLabels = warnings.map((w) => w.message).toList();
        expect(warningLabels, anyElement(contains('Heater')));
        expect(warningLabels, anyElement(contains('ProvisionListener')));
      });

      // ── Entry-Point Name Conflict Detection ─────────

      test('reports error for same-name getters with different qualifiers but same return type', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brand = Qualifier(#brand);
          const model = Qualifier(#model);

          abstract class BrandProvider {
            @inject
            @brand
            String get label;
          }

          abstract class ModelProvider {
            @inject
            @model
            String get label;
          }

          @component
          abstract class CarComponent implements BrandProvider, ModelProvider {}
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CarComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        final DiagnosticMessage error = reporter.messages.first;
        expect(error.message, contains("Entry point 'label'"));
        expect(error.message, contains('conflicting qualifiers'));
        expect(error.message, contains('#brand'));
        expect(error.message, contains('#model'));
        expect(error.message, contains('BrandProvider'));
        expect(error.message, contains('ModelProvider'));
      });

      test('reports error for same-name getters with different return types', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brand = Qualifier(#brand);
          const model = Qualifier(#model);

          abstract class BrandProvider {
            @inject
            @brand
            String get label;
          }

          abstract class ModelProvider {
            @inject
            @model
            int get label;
          }

          @component
          abstract class CarComponent implements BrandProvider, ModelProvider {}
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CarComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        final DiagnosticMessage error = reporter.messages.first;
        expect(error.message, contains("Entry point 'label'"));
        expect(error.message, contains('incompatible return types'));
        expect(error.message, contains('BrandProvider'));
        expect(error.message, contains('ModelProvider'));
      });

      test('no conflict for same-name getters with identical binding identity', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brand = Qualifier(#brand);

          abstract class BrandA {
            @inject
            @brand
            String get label;
          }

          abstract class BrandB {
            @inject
            @brand
            String get label;
          }

          @component
          abstract class DualBrandComponent implements BrandA, BrandB {}
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('DualBrandComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [],
          injectables: [],
        );

        // No conflict — the dedup in ComponentReader already collapsed
        // the two identical entries to one. Only downstream binding errors
        // may appear (missing binding), but no name-conflict error.
        final Iterable<DiagnosticMessage> conflictErrors = reporter.messages.where(
          (m) => m.message.contains('conflicting qualifiers') || m.message.contains('incompatible return types'),
        );
        expect(conflictErrors, isEmpty);
      });

      test('reports error for same-name methods with different qualifiers from interfaces', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const fast = Qualifier(#fast);
          const slow = Qualifier(#slow);

          abstract class FastProvider {
            @inject
            @fast
            String getSpeed();
          }

          abstract class SlowProvider {
            @inject
            @slow
            String getSpeed();
          }

          @component
          abstract class EngineComponent implements FastProvider, SlowProvider {}
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('EngineComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final DiagnosticMessage error = reporter.messages.first;
        expect(error.message, contains("Entry point 'getSpeed'"));
        expect(error.message, contains('conflicting qualifiers'));
      });

      test('suppresses downstream binding errors for conflicting entry points', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brand = Qualifier(#brand);
          const model = Qualifier(#model);

          abstract class BrandProvider {
            @inject
            @brand
            String get label;
          }

          abstract class ModelProvider {
            @inject
            @model
            String get label;
          }

          @module
          class CarModule {
            @provides
            @brand
            String provideBrand() => 'BMW';

            @provides
            @model
            String provideModel() => 'M3';
          }

          @Component([CarModule])
          abstract class CarComponent implements BrandProvider, ModelProvider {}
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('CarComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('CarModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        validator.validate(
          sourceLibrary: library,
          componentClass: componentClass,
          componentData: componentData,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        // Should have exactly the conflict error, no downstream binding errors
        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        expect(reporter.messages.first.message, contains('conflicting qualifiers'));
        // No "No binding found" errors
        final Iterable<DiagnosticMessage> bindingErrors = reporter.messages.where(
          (m) => m.message.contains('No binding found'),
        );
        expect(bindingErrors, isEmpty);
      });
    });
  });
}
