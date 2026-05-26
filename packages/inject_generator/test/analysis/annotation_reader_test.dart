import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/assisted_reader.dart';
import 'package:inject_generator/src/analysis/component_reader.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:test/test.dart';

/// Resolves [source] and returns the [LibraryElement] for assertions.
Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late AnnotationReader reader;

  setUp(() {
    reporter = DiagnosticReporter();
    reader = AnnotationReader(reporter: reporter);
  });

  group('AnnotationReader', () {
    group('isComponent', () {
      test('returns true for @component-annotated abstract class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @component
          abstract class CoffeeShop {}
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        expect(reader.isComponent(classElement), isTrue);
      });

      test('returns false for unannotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PlainService {}
        ''');

        final ClassElement classElement = library.getClass('PlainService')!;
        expect(reader.isComponent(classElement), isFalse);
      });
    });

    group('isModule', () {
      test('returns true for @module-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class DripCoffeeModule {}
        ''');

        final ClassElement classElement = library.getClass('DripCoffeeModule')!;
        expect(reader.isModule(classElement), isTrue);
      });
    });

    group('isInjectable', () {
      test('returns true for @inject-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class CoffeeMaker {}
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        expect(reader.isInjectable(classElement), isTrue);
      });

      test('returns true for class with @inject on unnamed constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {
            @inject
            CoffeeMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        expect(reader.isInjectable(classElement), isTrue);
      });

      test('returns false for class without @inject', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class PlainService {}
        ''');

        final ClassElement classElement = library.getClass('PlainService')!;
        expect(reader.isInjectable(classElement), isFalse);
      });

      test('returns true for class with @inject on named constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {
            @inject
            CoffeeMaker.withHeater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        expect(reader.isInjectable(classElement), isTrue);
      });

      test('returns true for class with @inject on factory constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          abstract class Service {
            @inject
            factory Service() = _ServiceImpl;
          }
          class _ServiceImpl implements Service {
            _ServiceImpl();
          }
        ''');

        final ClassElement classElement = library.getClass('Service')!;
        expect(reader.isInjectable(classElement), isTrue);
      });
    });

    group('isSingleton', () {
      test('returns true for @singleton-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          @singleton
          class DatabaseService {}
        ''');

        final ClassElement classElement = library.getClass('DatabaseService')!;
        expect(reader.isSingleton(classElement), isTrue);
      });
    });

    group('isAsynchronous', () {
      test('returns true for @asynchronous-annotated method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class CarModule {
            @provides
            @asynchronous
            Future<String> provideApiKey() async => 'key-123';
          }
        ''');

        final ClassElement classElement = library.getClass('CarModule')!;
        final MethodElement methodElement = classElement.getMethod('provideApiKey')!;
        expect(reader.isAsynchronous(methodElement), isTrue);
      });
    });

    group('hasQualifier', () {
      test('returns true for @Qualifier(#name)-annotated method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const baseUri = Qualifier(#baseUri);

          @module
          class RpcModule {
            @provides
            @baseUri
            String provideBaseUri() => 'https://example.com';
          }
        ''');

        final ClassElement classElement = library.getClass('RpcModule')!;
        final MethodElement methodElement = classElement.getMethod('provideBaseUri')!;
        expect(reader.hasQualifier(methodElement), isTrue);
      });
    });

    group('hasProvides', () {
      test('returns true for @provides-annotated method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class CoffeeModule {
            @provides
            String provideName() => 'Espresso';
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final MethodElement methodElement = classElement.getMethod('provideName')!;
        expect(reader.hasProvides(methodElement), isTrue);
      });
    });

    group('isProvisionListener', () {
      test('returns true for @provisionListener-annotated method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }

          @module
          class AppModule {
            @provides
            @provisionListener
            ProvisionListener<Object> provideListener() => LoggingListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final MethodElement methodElement = classElement.getMethod('provideListener')!;
        expect(reader.isProvisionListener(methodElement), isTrue);
      });

      test('returns false for method without @provisionListener', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideName() => 'hello';
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final MethodElement methodElement = classElement.getMethod('provideName')!;
        expect(reader.isProvisionListener(methodElement), isFalse);
      });
    });

    group('cross-isolation', () {
      test('isComponent returns false for @module-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class DripCoffeeModule {}
        ''');

        final ClassElement classElement = library.getClass('DripCoffeeModule')!;
        expect(reader.isComponent(classElement), isFalse);
      });
    });

    group('reporter reference', () {
      test('holds a DiagnosticReporter reference without emitting diagnostics', () {
        expect(reader.reporter, same(reporter));
        expect(reporter.messages, isEmpty);
      });
    });

    group('readComponent', () {
      test('delegates to ComponentReader and returns module list and entry points', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class DripCoffeeModule {}

          class CoffeeMaker {}

          @Component([DripCoffeeModule])
          abstract class CoffeeShop {
            @inject
            CoffeeMaker get coffeeMaker;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = reader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules, hasLength(1));
        expect(result.modules.first.element?.name, 'DripCoffeeModule');
        expect(result.entryPoints, hasLength(1));
      });
    });

    group('readModule', () {
      test('delegates to ModuleReader and returns provider descriptors', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            @singleton
            Heater provideHeater() => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = reader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.method.name, 'provideHeater');
        expect(result.providers.first.metadata.isSingleton, isTrue);
      });
    });

    group('readInjectable', () {
      test('delegates to InjectReader and returns constructor deps', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}
          class Pump {}

          class CoffeeMaker {
            @inject
            CoffeeMaker(Heater heater, Pump pump);
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = reader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.dependencies, hasLength(2));
        expect(result.dependencies[0].type.element?.name, 'Heater');
        expect(result.dependencies[1].type.element?.name, 'Pump');
      });
    });

    group('isAssistedInject', () {
      test('returns true for class with @assistedInject constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        expect(reader.isAssistedInject(classElement), isTrue);
      });

      test('returns false for unannotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PlainService {}
        ''');

        final ClassElement classElement = library.getClass('PlainService')!;
        expect(reader.isAssistedInject(classElement), isFalse);
      });

      test('returns true for class with @assistedInject on named constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService.create(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        expect(reader.isAssistedInject(classElement), isTrue);
      });
    });

    group('isAssistedFactory', () {
      test('returns true for @assistedFactory-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }

          @assistedFactory
          abstract class MyServiceFactory {
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyServiceFactory')!;
        expect(reader.isAssistedFactory(classElement), isTrue);
      });

      test('returns false for unannotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PlainService {}
        ''');

        final ClassElement classElement = library.getClass('PlainService')!;
        expect(reader.isAssistedFactory(classElement), isFalse);
      });
    });

    group('readAssistedInject', () {
      test('delegates to AssistedReader and returns data', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeService {}

          class MyService {
            @assistedInject
            MyService(@assisted String name, CoffeeService coffee);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final AssistedInjectData? result = reader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.assistedParameters, hasLength(1));
        expect(result.injectedDependencies, hasLength(1));
      });
    });

    group('readAssistedFactory', () {
      test('delegates to AssistedReader and returns data', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }

          @assistedFactory
          abstract class MyServiceFactory {
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyServiceFactory')!;
        final AssistedFactoryData? result = reader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.createMethod.name, 'create');
        expect(result.targetType.element?.name, 'MyService');
      });
    });
  });
}
