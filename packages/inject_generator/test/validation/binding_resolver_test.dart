import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/dependency_discovery.dart';
import 'package:inject_generator/src/builder/inject_builder_options.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late BindingResolver resolver;

  setUp(() {
    reporter = DiagnosticReporter();
    resolver = BindingResolver(reporter: reporter);
  });

  group('BindingResolver', () {
    group('resolve', () {
      // ── Missing Bindings ──────────────────────────────────────────

      test('reports error for unresolvable dependency type', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class UnknownService {}

          @module
          class AppModule {
            @provides
            String provideGreeting(UnknownService service) => 'hello';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('UnknownService')), isTrue);
      });

      test('reports error with suggestion for missing module provider', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class MissingDep {}

          @module
          class AppModule {
            @provides
            String provideGreeting(MissingDep dep) => 'hello';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.suggestion!.contains('@provides')), isTrue);
      });

      test('allows dependency provided by module', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            int provideCount() => 42;

            @provides
            String provideGreeting(int count) => 'hello \$count';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('allows dependency provided by @inject class', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class Engine {
            Engine();
          }

          @inject
          class Car {
            final Engine engine;
            Car(this.engine);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final engineClass = library.getClass('Engine')!;
        final engineData = reader.readInjectable(engineClass)!;
        final carClass = library.getClass('Car')!;
        final carData = reader.readInjectable(carClass)!;

        resolver.resolve(
          modules: [],
          injectables: [
            (classElement: engineClass, injectable: engineData),
            (classElement: carClass, injectable: carData),
          ],
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('reports all missing bindings without stopping early', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class MissingA {}
          abstract class MissingB {}
          abstract class MissingC {}

          @module
          class AppModule {
            @provides
            String provideAll(MissingA a, MissingB b, MissingC c) => 'x';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, greaterThanOrEqualTo(3));
      });

      // ── Generics und Unannotated Classes ──────────────────────────

      test('resolves generic type List<String> as binding without loop', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            List<String> provideNames() => ['a', 'b'];

            @provides
            String provideFirst(List<String> names) => names.first;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isFalse);
      });

      test('resolves nested generic type List<Comparable<String>> without loop', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            List<Comparable<String>> provideComparables() => [];

            @provides
            int provideCount(List<Comparable<String>> items) => items.length;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isFalse);
      });

      test('emits error for unannotated class in dependency graph', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class PlainService {}

          @module
          class AppModule {
            @provides
            String provideGreeting(PlainService svc) => 'hello';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.warningCount, equals(0));
        expect(reporter.messages.any((m) => m.message.contains('No binding found')), isTrue);
        expect(reporter.messages.any((m) => m.message.contains('PlainService')), isTrue);
        expect(reporter.messages.any((m) => m.suggestion!.contains('annotate the class with @inject')), isTrue);
      });

      test('emits error for unannotated class without default constructor', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class NoDefaultCtor {
            NoDefaultCtor._(int x);
          }

          @module
          class AppModule {
            @provides
            String provideGreeting(NoDefaultCtor svc) => 'hello';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('NoDefaultCtor')), isTrue);
      });

      test('emits error for unsupported record type in dependency', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideGreeting((int, String) record) => 'hello';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('Record type')), isTrue);
      });

      // ── Entry-Point Validation ────────────────────────────────────

      test('reports error for entry-point type with no binding', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class MissingService {}

          @Component([])
          abstract class AppComponent {
            @inject
            MissingService get service;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final componentClass = library.getClass('AppComponent')!;
        final componentData = reader.readComponent(componentClass)!;

        resolver.resolve(modules: [], injectables: [], entryPoints: componentData.entryPoints);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('MissingService')), isTrue);
        expect(reporter.messages.any((m) => m.message.contains('entry-point')), isTrue);
      });

      test('allows entry-point type with matching binding', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideName() => 'hello';
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final componentClass = library.getClass('AppComponent')!;
        final componentData = reader.readComponent(componentClass)!;

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
      });

      // ── Qualified Entry-Point Key Propagation ─────────────────────

      test('resolves qualified and unqualified entry points of same type independently', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);

          @module
          class AppModule {
            @provides
            String provideName() => 'default';

            @provides
            @brandName
            String provideBrand() => 'premium';
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;

            @inject
            @brandName
            String get brand;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final componentClass = library.getClass('AppComponent')!;
        final componentData = reader.readComponent(componentClass)!;

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
      });

      test('reports error when qualified entry-point has no matching qualified binding', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);

          @module
          class AppModule {
            @provides
            String provideName() => 'default';
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            @brandName
            String get brand;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final componentClass = library.getClass('AppComponent')!;
        final componentData = reader.readComponent(componentClass)!;

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isTrue);
        // Scenario 2: qualified entry-point with unqualified binding available
        expect(reporter.messages.any((m) => m.message.contains('No binding for')), isTrue);
        expect(reporter.messages.any((m) => m.message.contains('#brandName')), isTrue);
        expect(reporter.messages.any((m) => m.message.contains('exposed by')), isTrue);
        expect(reporter.messages.any((m) => m.suggestion!.contains('unqualified')), isTrue);
      });

      // ── Qualifier Mismatch Diagnostics ────────────────────────────

      group('qualifier mismatch diagnostics', () {
        // Scenario 1: Unqualified requested, only qualified exist
        test('lists available qualifiers when unqualified dependency is missing but qualified exist', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const apiKey = Qualifier(#apiKey);
            const baseUri = Qualifier(#baseUri);

            @module
            class AppModule {
              @provides
              @apiKey
              String provideApiKey() => 'key-123';

              @provides
              @baseUri
              String provideBaseUri() => 'https://api.example.com';

              @provides
              int provideCount(String name) => name.length;
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final moduleClass = library.getClass('AppModule')!;
          final moduleData = reader.readModule(moduleClass);

          resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('No unqualified binding'));
          expect(msg.message, contains('String'));
          expect(msg.suggestion, contains('#apiKey'));
          expect(msg.suggestion, contains('#baseUri'));
          expect(msg.suggestion, contains('(from AppModule.provideApiKey)'));
          expect(msg.suggestion, contains('injection site'));
        });

        test('lists available qualifiers for unqualified entry-point', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const apiKey = Qualifier(#apiKey);
            const baseUri = Qualifier(#baseUri);

            @module
            class AppModule {
              @provides
              @apiKey
              String provideApiKey() => 'key-123';

              @provides
              @baseUri
              String provideBaseUri() => 'https://api.example.com';
            }

            @Component([AppModule])
            abstract class AppComponent {
              @inject
              String get name;
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final moduleClass = library.getClass('AppModule')!;
          final moduleData = reader.readModule(moduleClass);
          final componentClass = library.getClass('AppComponent')!;
          final componentData = reader.readComponent(componentClass)!;

          resolver.resolve(
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            injectables: [],
            entryPoints: componentData.entryPoints,
          );

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('No unqualified binding'));
          expect(msg.message, contains('String'));
          expect(msg.message, contains('exposed by'));
          expect(msg.suggestion, contains('#apiKey'));
          expect(msg.suggestion, contains('#baseUri'));
          expect(msg.suggestion, contains('(from AppModule.provideApiKey)'));
          expect(msg.suggestion, contains('component accessor'));
        });

        // Scenario 2: Wrong qualifier requested, other qualifiers exist
        test('lists available bindings when wrong qualifier requested', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const apiKey = Qualifier(#apiKey);
            const config = Qualifier(#config);

            @module
            class AppModule {
              @provides
              @apiKey
              String provideApiKey() => 'key-123';

              @provides
              int provideCount(@config String cfg) => cfg.length;
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final moduleClass = library.getClass('AppModule')!;
          final moduleData = reader.readModule(moduleClass);

          resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('No binding for'));
          expect(msg.message, contains('#config'));
          expect(msg.suggestion, contains('#apiKey'));
          expect(msg.suggestion, contains('(from AppModule.provideApiKey)'));
        });

        test('shows both qualified and unqualified when wrong qualifier requested', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const apiKey = Qualifier(#apiKey);
            const config = Qualifier(#config);

            @module
            class AppModule {
              @provides
              String provideDefault() => 'default';

              @provides
              @apiKey
              String provideApiKey() => 'key-123';

              @provides
              int provideCount(@config String cfg) => cfg.length;
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final moduleClass = library.getClass('AppModule')!;
          final moduleData = reader.readModule(moduleClass);

          resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('#config'));
          expect(msg.suggestion, contains('unqualified'));
          expect(msg.suggestion, contains('#apiKey'));
        });

        // Scenario 3: No related bindings at all → standard message
        test('falls back to standard message when no bindings for type exist', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            abstract class UnknownService {}

            @module
            class AppModule {
              @provides
              String provideGreeting(UnknownService service) => 'hello';
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final moduleClass = library.getClass('AppModule')!;
          final moduleData = reader.readModule(moduleClass);

          resolver.resolve(modules: [(moduleClass: moduleClass, moduleData: moduleData)], injectables: []);

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('No binding found for type'));
          expect(msg.suggestion, contains('Add a @provides method'));
        });

        test('standard missing binding messages unchanged for non-qualifier scenarios', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            @Component([])
            abstract class AppComponent {
              @inject
              int get count;
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final componentClass = library.getClass('AppComponent')!;
          final componentData = reader.readComponent(componentClass)!;

          resolver.resolve(modules: [], injectables: [], entryPoints: componentData.entryPoints);

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('No binding found for entry-point type'));
          expect(msg.suggestion, contains('Add a @provides method'));
        });

        test('shows qualifier mismatch for @inject constructor path', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const prod = Qualifier(#prod);

            class ApiClient {
              @inject
              @prod
              ApiClient();
            }

            @module
            class AppModule {
              @provides
              String provideGreeting(ApiClient client) => 'hello';
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final moduleClass = library.getClass('AppModule')!;
          final moduleData = reader.readModule(moduleClass);
          final injectableClass = library.getClass('ApiClient')!;
          final injectableData = reader.readInjectable(injectableClass)!;

          resolver.resolve(
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            injectables: [(classElement: injectableClass, injectable: injectableData)],
          );

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('No unqualified binding'));
          expect(msg.message, contains('ApiClient'));
          expect(msg.suggestion, contains('#prod'));
          expect(msg.suggestion, contains('(from ApiClient (constructor injection))'));
        });

        test('shows named constructor origin in qualifier mismatch diagnostic', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const prod = Qualifier(#prod);

            class ApiClient {
              @inject
              @prod
              ApiClient.named();
            }

            @module
            class AppModule {
              @provides
              String provideGreeting(ApiClient client) => 'hello';
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final moduleClass = library.getClass('AppModule')!;
          final moduleData = reader.readModule(moduleClass);
          final injectableClass = library.getClass('ApiClient')!;
          final injectableData = reader.readInjectable(injectableClass)!;

          resolver.resolve(
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            injectables: [(classElement: injectableClass, injectable: injectableData)],
          );

          expect(reporter.hasErrors, isTrue);
          final msg = reporter.messages.single;
          expect(msg.message, contains('No unqualified binding'));
          expect(msg.message, contains('ApiClient'));
          expect(msg.suggestion, contains('#prod'));
          expect(msg.suggestion, contains('(from ApiClient.named (constructor injection))'));
        });
      });

      // ── Factory Dependency Validation ─────────────────────────────

      test('reports error for missing factory dependency', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class MissingService {}

          class Widget {
            @assistedInject
            Widget(MissingService service, @assisted String label);
          }

          @assistedFactory
          abstract class WidgetFactory {
            Widget create(String label);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final factoryClass = library.getClass('WidgetFactory')!;
        final injectClass = library.getClass('Widget')!;
        final factoryData = reader.readAssistedFactory(factoryClass)!;
        final injectData = reader.readAssistedInject(injectClass)!;

        resolver.resolve(
          modules: [],
          injectables: [],
          factories: [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)],
        );

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('MissingService')), isTrue);
      });

      test('allows factory dependency provided by module', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            int provideCount() => 42;
          }

          class Widget {
            @assistedInject
            Widget(int count, @assisted String label);
          }

          @assistedFactory
          abstract class WidgetFactory {
            Widget create(String label);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final factoryClass = library.getClass('WidgetFactory')!;
        final injectClass = library.getClass('Widget')!;
        final factoryData = reader.readAssistedFactory(factoryClass)!;
        final injectData = reader.readAssistedInject(injectClass)!;

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          factories: [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)],
        );

        expect(reporter.hasErrors, isFalse);
      });

      // ── Nullable-Widening Resolution ──────────────────────────────

      test('resolves nullable dep Foo? from non-nullable Foo @inject binding', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Dep {
            @inject
            Dep();
          }

          class Consumer {
            @inject
            Consumer(Dep? dep);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final depClass = library.getClass('Dep')!;
        final consumerClass = library.getClass('Consumer')!;
        final depData = reader.readInjectable(depClass)!;
        final consumerData = reader.readInjectable(consumerClass)!;

        resolver.resolve(
          modules: [],
          injectables: [
            (classElement: depClass, injectable: depData),
            (classElement: consumerClass, injectable: consumerData),
          ],
        );

        expect(reporter.hasErrors, isFalse, reason: 'Foo? dep must widen to Foo non-nullable binding');
      });

      test('resolves nullable factory dep Foo? from non-nullable Foo module binding', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Service {}

          @module
          class AppModule {
            @provides
            Service provideService() => throw UnimplementedError();
          }

          class Widget {
            @assistedInject
            Widget(Service? service, @assisted String label);
          }

          @assistedFactory
          abstract class WidgetFactory {
            Widget create(String label);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final factoryClass = library.getClass('WidgetFactory')!;
        final widgetClass = library.getClass('Widget')!;
        final factoryData = reader.readAssistedFactory(factoryClass)!;
        final injectData = reader.readAssistedInject(widgetClass)!;

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          factories: [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)],
        );

        expect(reporter.hasErrors, isFalse, reason: 'nullable factory dep must widen to non-nullable module binding');
      });

      test('emits error with "also tried" when neither Foo? nor Foo is bound', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Missing {}

          class Consumer {
            @inject
            Consumer(Missing? dep);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final consumerClass = library.getClass('Consumer')!;
        final consumerData = reader.readInjectable(consumerClass)!;

        resolver.resolve(
          modules: [],
          injectables: [(classElement: consumerClass, injectable: consumerData)],
        );

        expect(reporter.hasErrors, isTrue);
        final combined = reporter.messages.map((m) => m.message).join('\n');
        expect(combined, contains('Missing?'));
        expect(combined, contains('also tried'));
        expect(combined, contains("'Missing'"));
      });

      // ── _validateDependencies: typedef providers ──────────────────────────

      group('_validateDependencies / typedef providers', () {
        test('reports missing binding for typedef-provider injected parameter', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            class UnboundService {}

            class TestBuilder<T> {
              TestBuilder(UnboundService dep);
            }
            typedef TestFactory<T> = TestBuilder<T> Function(T value);

            class MyClass {
              @assistedInject
              MyClass(TestFactory<String> factory, @assisted int id);
            }

            @assistedFactory
            abstract class IMyFactory {
              MyClass create(int id);
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final factoryClass = library.getClass('IMyFactory')!;
          final injectClass = library.getClass('MyClass')!;
          final factoryData = reader.readAssistedFactory(factoryClass)!;
          final injectData = reader.readAssistedInject(injectClass)!;

          final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
          final typedefProviders = <TypedefProviderData>[];

          discoverTypedefProviders(
            reader: reader,
            factories: factories,
            injectables: [],
            modules: [],
            typedefProviders: typedefProviders,
          );

          expect(typedefProviders, isNotEmpty, reason: 'fixture must produce at least one typedef provider');

          resolver.resolve(
            modules: [],
            injectables: [],
            factories: factories,
            typedefProviders: typedefProviders,
          );

          expect(reporter.hasErrors, isTrue);
          expect(
            reporter.messages.any((m) => m.message.contains('No binding found')),
            isTrue,
            reason: 'missing binding for typedef-provider injected param must be reported',
          );
        });

        test('preserves @Qualifier on typedef-provider injected parameter', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const apiKey = Qualifier(#apiKey);

            class TestBuilder<T> {
              TestBuilder(@apiKey String key);
            }
            typedef TestFactory<T> = TestBuilder<T> Function(T value);

            @module
            class AppModule {
              @provides
              String provideUnqualified() => 'unqualified';

              @provides
              @apiKey
              String provideQualified() => 'qualified';
            }

            class MyClass {
              @assistedInject
              MyClass(TestFactory<String> factory, @assisted int id);
            }

            @assistedFactory
            abstract class IMyFactory {
              MyClass create(int id);
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final factoryClass = library.getClass('IMyFactory')!;
          final injectClass = library.getClass('MyClass')!;
          final moduleClass = library.getClass('AppModule')!;
          final factoryData = reader.readAssistedFactory(factoryClass)!;
          final injectData = reader.readAssistedInject(injectClass)!;
          final moduleData = reader.readModule(moduleClass);

          final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
          final typedefProviders = <TypedefProviderData>[];

          discoverTypedefProviders(
            reader: reader,
            factories: factories,
            injectables: [],
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            typedefProviders: typedefProviders,
          );

          expect(typedefProviders, isNotEmpty);
          // injectedParams must carry the @apiKey qualifier — otherwise the
          // resolver would silently match the unqualified String binding.
          final injectedParam = typedefProviders.first.injectedParams.single;
          expect(injectedParam.qualifier, equals('apiKey'));

          final result = resolver.resolve(
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            injectables: [],
            factories: factories,
            typedefProviders: typedefProviders,
          );

          expect(reporter.hasErrors, isFalse, reason: 'qualified binding must satisfy qualified typedef-provider dep');

          // _dependencyEdges must encode the qualifier — proves binding identity
          // (type, qualifier) is preserved through validation.
          final typedefKey = result.bindingMap.keys.firstWhere(
            (k) => k.debugLabel.contains('TestFactory'),
          );
          final typedefEdges = result.dependencyEdges[typedefKey]!;
          expect(typedefEdges, hasLength(1));
          expect(typedefEdges.single.qualifier, equals('apiKey'));
        });

        test('reports missing binding when typedef-provider param is qualified but only unqualified binding exists',
            () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            const apiKey = Qualifier(#apiKey);

            class TestBuilder<T> {
              TestBuilder(@apiKey String key);
            }
            typedef TestFactory<T> = TestBuilder<T> Function(T value);

            @module
            class AppModule {
              @provides
              String provideUnqualified() => 'unqualified';
            }

            class MyClass {
              @assistedInject
              MyClass(TestFactory<String> factory, @assisted int id);
            }

            @assistedFactory
            abstract class IMyFactory {
              MyClass create(int id);
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final factoryClass = library.getClass('IMyFactory')!;
          final injectClass = library.getClass('MyClass')!;
          final moduleClass = library.getClass('AppModule')!;
          final factoryData = reader.readAssistedFactory(factoryClass)!;
          final injectData = reader.readAssistedInject(injectClass)!;
          final moduleData = reader.readModule(moduleClass);

          final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
          final typedefProviders = <TypedefProviderData>[];

          discoverTypedefProviders(
            reader: reader,
            factories: factories,
            injectables: [],
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            typedefProviders: typedefProviders,
          );

          expect(typedefProviders, isNotEmpty);
          expect(
            typedefProviders.first.injectedParams.single.qualifier,
            equals('apiKey'),
            reason: 'typedef-provider injected param must carry the @apiKey qualifier',
          );

          resolver.resolve(
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            injectables: [],
            factories: factories,
            typedefProviders: typedefProviders,
          );

          expect(
            reporter.hasErrors,
            isTrue,
            reason: 'unqualified String binding must NOT silently satisfy @apiKey String dep',
          );
          // The qualifier-mismatch path surfaces the unqualified binding as a
          // related candidate — "No binding for 'String (#apiKey)' ...". The
          // key invariant is that the diagnostic mentions the requested qualifier.
          expect(
            reporter.messages.any((m) => m.message.contains('#apiKey')),
            isTrue,
            reason: 'diagnostic must reference the requested @apiKey qualifier',
          );
        });

        test('nullable typedef-provider param is satisfied by non-nullable binding via widening', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            class Dep {}

            class TestBuilder<T> {
              TestBuilder(Dep? maybeDep);
            }
            typedef TestFactory<T> = TestBuilder<T> Function(T value);

            @module
            class AppModule {
              @provides
              Dep provideDep() => Dep();
            }

            class MyClass {
              @assistedInject
              MyClass(TestFactory<String> factory, @assisted int id);
            }

            @assistedFactory
            abstract class IMyFactory {
              MyClass create(int id);
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final factoryClass = library.getClass('IMyFactory')!;
          final injectClass = library.getClass('MyClass')!;
          final moduleClass = library.getClass('AppModule')!;
          final factoryData = reader.readAssistedFactory(factoryClass)!;
          final injectData = reader.readAssistedInject(injectClass)!;
          final moduleData = reader.readModule(moduleClass);

          final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
          final typedefProviders = <TypedefProviderData>[];

          discoverTypedefProviders(
            reader: reader,
            factories: factories,
            injectables: [],
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            typedefProviders: typedefProviders,
          );

          resolver.resolve(
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            injectables: [],
            factories: factories,
            typedefProviders: typedefProviders,
          );

          expect(reporter.hasErrors, isFalse, reason: 'Dep? param must widen against unqualified Dep binding');
        });

        test('Provider<T> typedef-provider param resolves against the inner T binding', () async {
          final library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            class Dep {}

            class TestBuilder<T> {
              TestBuilder(Provider<Dep> depProvider);
            }
            typedef TestFactory<T> = TestBuilder<T> Function(T value);

            @module
            class AppModule {
              @provides
              Dep provideDep() => Dep();
            }

            class MyClass {
              @assistedInject
              MyClass(TestFactory<String> factory, @assisted int id);
            }

            @assistedFactory
            abstract class IMyFactory {
              MyClass create(int id);
            }
          ''');

          final reader = AnnotationReader(reporter: reporter);
          final factoryClass = library.getClass('IMyFactory')!;
          final injectClass = library.getClass('MyClass')!;
          final moduleClass = library.getClass('AppModule')!;
          final factoryData = reader.readAssistedFactory(factoryClass)!;
          final injectData = reader.readAssistedInject(injectClass)!;
          final moduleData = reader.readModule(moduleClass);

          final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
          final typedefProviders = <TypedefProviderData>[];

          discoverTypedefProviders(
            reader: reader,
            factories: factories,
            injectables: [],
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            typedefProviders: typedefProviders,
          );

          expect(typedefProviders, isNotEmpty);
          // Provider<T> wrap is unwrapped during discovery — depType is Dep,
          // passProvider is true so codegen emits the field reference instead
          // of calling .get().
          final injected = typedefProviders.first.injectedParams.single;
          expect(injected.passProvider, isTrue);
          expect(injected.depType.getDisplayString(), equals('Dep'));

          resolver.resolve(
            modules: [(moduleClass: moduleClass, moduleData: moduleData)],
            injectables: [],
            factories: factories,
            typedefProviders: typedefProviders,
          );

          expect(reporter.hasErrors, isFalse, reason: 'Provider<Dep> param resolves against Dep binding');
        });
      });
    });

    // ── Nullable Duplicate Binding Policy ────────────────────────

    group('nullable duplicate binding policy', () {
      test('error policy (default) emits error when Foo and Foo? both bound from module', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Svc {}

          @module
          class AppModule {
            @provides
            Svc provideSvc() => throw UnimplementedError();

            @provides
            Svc? provideSvcNullable() => null;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        final result = resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        // Error path: diagnostic anchored to BOTH provider methods.
        expect(reporter.errorCount, 2, reason: 'error policy must double-anchor (newSource + existingSource)');
        final combined = reporter.messages.map((m) => m.formattedMessage).join('\n');
        expect(combined, contains('Duplicate binding for type'));
        expect(combined, contains('nullable'));
        expect(combined, contains('non-nullable'));
        expect(combined, contains('nullable_duplicate_binding_policy: allow'));
        // Library URI is included so monorepos can disambiguate same-named types.
        expect(combined, contains('package:'));
        // Error path discards the second binding; only one of the two key
        // variants survives in the binding map.
        expect(
          result.bindingMap.length,
          1,
          reason: 'error policy must discard the second registration; only one key remains',
        );
      });

      test('allow policy keeps both bindings and emits no diagnostic', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Svc {}

          @module
          class AppModule {
            @provides
            Svc provideSvc() => throw UnimplementedError();

            @provides
            Svc? provideSvcNullable() => null;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        final result = resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          nullableDuplicatePolicy: NullableDuplicatePolicy.allow,
        );

        expect(reporter.hasErrors, isFalse, reason: 'allow policy must not emit an error');
        expect(reporter.messages, isEmpty, reason: 'allow policy must emit no diagnostic at all');
        expect(
          result.bindingMap.keys.where((k) => !k.isNullable).length,
          1,
          reason: 'allow policy must keep the non-nullable binding',
        );
        expect(
          result.bindingMap.keys.where((k) => k.isNullable).length,
          1,
          reason: 'allow policy must keep the nullable binding',
        );
      });

      test('warn policy keeps both bindings and double-anchors the warning', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Svc {}

          @module
          class AppModule {
            @provides
            Svc provideSvc() => throw UnimplementedError();

            @provides
            Svc? provideSvcNullable() => null;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        final result = resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          nullableDuplicatePolicy: NullableDuplicatePolicy.warn,
        );

        expect(reporter.hasErrors, isFalse, reason: 'warn policy must not emit an error');
        expect(reporter.warningCount, 2, reason: 'warn policy must double-anchor (newSource + existingSource)');
        final combined = reporter.messages.map((m) => m.message).join('\n');
        expect(combined, contains('Duplicate binding for type'));
        // Warn suggestion is distinct: don't tell users to switch to 'allow'
        final firstSuggestion = reporter.messages.first.suggestion ?? '';
        expect(firstSuggestion, contains('silence this warning'));
        expect(firstSuggestion, isNot(contains("'allow'")));
        expect(
          result.bindingMap.keys.where((k) => !k.isNullable).length,
          1,
          reason: 'warn policy must keep the non-nullable binding',
        );
        expect(
          result.bindingMap.keys.where((k) => k.isNullable).length,
          1,
          reason: 'warn policy must keep the nullable binding',
        );
      });

      test('error policy does not trigger for different qualifier pairs (@Q Foo vs Foo?)', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const q = Qualifier(#q);
          abstract class Svc {}

          @module
          class AppModule {
            @provides
            @q
            Svc provideSvc() => throw UnimplementedError();

            @provides
            Svc? provideSvcNullable() => null;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        // @q Svc (qualified) and Svc? (unqualified) have different qualifier,
        // so they are distinct keys — no nullable-duplicate policy should apply.
        expect(reporter.hasErrors, isFalse, reason: 'different qualifiers are not a nullable duplicate');
      });

      test('error fires when @inject Foo collides with module Foo? (cross-category)', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class Svc {
            Svc();
          }

          @module
          class AppModule {
            @provides
            Svc? provideSvcNullable() => null;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final injectClass = library.getClass('Svc')!;
        final injectableData = reader.readInjectable(injectClass)!;

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [(classElement: injectClass, injectable: injectableData)],
        );

        expect(reporter.errorCount, 2, reason: 'cross-category conflict must double-anchor');
        final combined = reporter.messages.map((m) => m.formattedMessage).join('\n');
        expect(combined, contains('Duplicate binding for type'));
        expect(combined, contains('Svc'));
        final elementKinds = reporter.messages.map((m) => m.formattedMessage).toList().toSet();
        expect(elementKinds, isNotEmpty);
      });

      test('dedup-set fires policy at most once per (typeIdentity, qualifier) pair', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Svc {}

          @module
          class AppModule {
            @provides
            Svc provideSvc() => throw UnimplementedError();

            @provides
            Svc provideSvcAlt() => throw UnimplementedError();

            @provides
            Svc? provideSvcNullable() => null;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          nullableDuplicatePolicy: NullableDuplicatePolicy.warn,
        );

        // Two non-nullable + one nullable provider → exactly one logical
        // nullable-duplicate conflict → 2 warnings (double-anchor), not 4 or more.
        final nullableDupWarnings = reporter.messages
            .where((m) => m.message.contains('Duplicate binding for type'))
            .map((m) => m.message)
            .toList();
        expect(
          nullableDupWarnings,
          hasLength(2),
          reason: 'nullable-duplicate must dedupe across repeated triggers (double-anchor counts as 1 conflict)',
        );
      });

      test('warn policy writes dependencyEdges for both nullable and non-nullable binding', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Dep {}
          abstract class Svc {}

          @module
          class AppModule {
            @provides
            Dep provideDep() => Dep();

            @provides
            Svc provideSvc(Dep dep) => throw UnimplementedError();

            @provides
            Svc? provideSvcNullable(Dep dep) => null;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);

        final result = resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          nullableDuplicatePolicy: NullableDuplicatePolicy.warn,
        );

        expect(reporter.hasErrors, isFalse, reason: 'warn policy must not emit errors');
        final nullableKey = result.bindingMap.keys.firstWhere((k) => k.isNullable);
        final nonNullableSvcKey = result.bindingMap.keys.firstWhere(
          (k) => !k.isNullable && k.debugLabel == 'Svc',
        );
        expect(
          result.dependencyEdges.containsKey(nullableKey),
          isTrue,
          reason: 'warn policy must write dependencyEdges for the nullable binding',
        );
        expect(
          result.dependencyEdges.containsKey(nonNullableSvcKey),
          isTrue,
          reason: 'warn policy must write dependencyEdges for the non-nullable binding',
        );
        expect(
          result.dependencyEdges[nullableKey]!.toSet(),
          equals(result.dependencyEdges[nonNullableSvcKey]!.toSet()),
          reason:
              'discarded variant must point at the same deps as the surviving variant '
              '(same edges for both keys)',
        );
      });
    });
  });
}
