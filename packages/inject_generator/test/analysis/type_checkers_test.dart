import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/type_checkers.dart';
import 'package:test/test.dart';

/// Resolves [source] and returns the [LibraryElement] for assertions.
///
/// Wraps [resolveSource] with a default [AssetId] and extracts the library
/// element so each test reads cleanly. Uses `readAllSourcesFromFilesystem`
/// so that `package:inject_annotation` imports resolve against the real
/// package, enabling package-safe TypeChecker assertions.
Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  group('type_checkers', () {
    group('componentChecker', () {
      test('matches @component annotation', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @component
          abstract class CoffeeShop {}
        ''');

        final ClassElement? classElement = library.getClass('CoffeeShop');
        expect(classElement, isNotNull);
        expect(componentChecker.hasAnnotationOf(classElement!), isTrue);
      });

      test('matches @Component() constructor annotation', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @Component()
          abstract class CoffeeShop {}
        ''');

        final ClassElement? classElement = library.getClass('CoffeeShop');
        expect(classElement, isNotNull);
        expect(componentChecker.hasAnnotationOf(classElement!), isTrue);
      });

      test('does not match unannotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PlainService {}
        ''');

        final ClassElement? classElement = library.getClass('PlainService');
        expect(classElement, isNotNull);
        expect(componentChecker.hasAnnotationOf(classElement!), isFalse);
      });

      test('does not match a same-named class from another package', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Component {
            const Component._();
          }
          const component = Component._();

          @component
          abstract class FakeShop {}
        ''');

        final ClassElement? classElement = library.getClass('FakeShop');
        expect(classElement, isNotNull);
        expect(componentChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('moduleChecker', () {
      test('matches @module annotation', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class DripCoffeeModule {}
        ''');

        final ClassElement? classElement = library.getClass('DripCoffeeModule');
        expect(classElement, isNotNull);
        expect(moduleChecker.hasAnnotationOf(classElement!), isTrue);
      });

      test('does not match unannotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PlainModule {}
        ''');

        final ClassElement? classElement = library.getClass('PlainModule');
        expect(classElement, isNotNull);
        expect(moduleChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('injectChecker', () {
      test('matches @inject annotation on a class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class CoffeeMaker {}
        ''');

        final ClassElement? classElement = library.getClass('CoffeeMaker');
        expect(classElement, isNotNull);
        expect(injectChecker.hasAnnotationOf(classElement!), isTrue);
      });

      test('does not match unannotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PlainClass {}
        ''');

        final ClassElement? classElement = library.getClass('PlainClass');
        expect(classElement, isNotNull);
        expect(injectChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('providesChecker', () {
      test('matches @provides annotation on a method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class CoffeeModule {
            @provides
            String provideName() => 'Espresso';
          }
        ''');

        final ClassElement? classElement = library.getClass('CoffeeModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideName');
        expect(methodElement, isNotNull);
        expect(providesChecker.hasAnnotationOf(methodElement!), isTrue);
      });

      test('does not match unannotated method', () async {
        final LibraryElement library = await _resolveLibrary('''
          class SomeClass {
            String plainMethod() => 'hello';
          }
        ''');

        final ClassElement? classElement = library.getClass('SomeClass');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('plainMethod');
        expect(methodElement, isNotNull);
        expect(providesChecker.hasAnnotationOf(methodElement!), isFalse);
      });
    });

    group('singletonChecker', () {
      test('matches @singleton annotation on a class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          @singleton
          class DatabaseService {}
        ''');

        final ClassElement? classElement = library.getClass('DatabaseService');
        expect(classElement, isNotNull);
        expect(singletonChecker.hasAnnotationOf(classElement!), isTrue);
      });

      test('does not match class without @singleton', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class TransientService {}
        ''');

        final ClassElement? classElement = library.getClass('TransientService');
        expect(classElement, isNotNull);
        expect(singletonChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('asynchronousChecker', () {
      test('matches @asynchronous annotation on a method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class CarModule {
            @provides
            @asynchronous
            Future<String> provideApiKey() async => 'key-123';
          }
        ''');

        final ClassElement? classElement = library.getClass('CarModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideApiKey');
        expect(methodElement, isNotNull);
        expect(asynchronousChecker.hasAnnotationOf(methodElement!), isTrue);
      });

      test('does not match method without @asynchronous', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class SyncModule {
            @provides
            String provideSync() => 'sync';
          }
        ''');

        final ClassElement? classElement = library.getClass('SyncModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideSync');
        expect(methodElement, isNotNull);
        expect(asynchronousChecker.hasAnnotationOf(methodElement!), isFalse);
      });
    });

    group('qualifierChecker', () {
      test('matches @Qualifier annotation on a method', () async {
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

        final ClassElement? classElement = library.getClass('RpcModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideBaseUri');
        expect(methodElement, isNotNull);
        expect(qualifierChecker.hasAnnotationOf(methodElement!), isTrue);
      });

      test('does not match method without qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class SimpleModule {
            @provides
            String provideValue() => 'value';
          }
        ''');

        final ClassElement? classElement = library.getClass('SimpleModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideValue');
        expect(methodElement, isNotNull);
        expect(qualifierChecker.hasAnnotationOf(methodElement!), isFalse);
      });
    });

    group('assistedInjectChecker', () {
      test('matches @assistedInject annotation on a class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @assistedInject
          class PaymentProcessor {
            PaymentProcessor(@assisted String orderId);
          }
        ''');

        final ClassElement? classElement = library.getClass('PaymentProcessor');
        expect(classElement, isNotNull);
        expect(assistedInjectChecker.hasAnnotationOf(classElement!), isTrue);
      });

      test('does not match class without @assistedInject', () async {
        final LibraryElement library = await _resolveLibrary('''
          class RegularClass {}
        ''');

        final ClassElement? classElement = library.getClass('RegularClass');
        expect(classElement, isNotNull);
        expect(assistedInjectChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('assistedChecker', () {
      test('matches @assisted annotation on a parameter', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @assistedInject
          class Processor {
            Processor(@assisted String orderId);
          }
        ''');

        final ClassElement? classElement = library.getClass('Processor');
        expect(classElement, isNotNull);
        final ConstructorElement? constructorElement = classElement!.unnamedConstructor;
        expect(constructorElement, isNotNull);
        final FormalParameterElement parameterElement = constructorElement!.formalParameters.first;
        expect(assistedChecker.hasAnnotationOf(parameterElement), isTrue);
      });

      test('does not match parameter without @assisted', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class SimpleService {
            SimpleService(String name);
          }
        ''');

        final ClassElement? classElement = library.getClass('SimpleService');
        expect(classElement, isNotNull);
        final ConstructorElement? constructorElement = classElement!.unnamedConstructor;
        expect(constructorElement, isNotNull);
        final FormalParameterElement parameterElement = constructorElement!.formalParameters.first;
        expect(assistedChecker.hasAnnotationOf(parameterElement), isFalse);
      });
    });

    group('assistedFactoryChecker', () {
      test('matches @assistedFactory annotation on a class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @assistedFactory
          abstract class ProcessorFactory {
            Processor create(String orderId);
          }

          class Processor {}
        ''');

        final ClassElement? classElement = library.getClass('ProcessorFactory');
        expect(classElement, isNotNull);
        expect(assistedFactoryChecker.hasAnnotationOf(classElement!), isTrue);
      });

      test('does not match class without @assistedFactory', () async {
        final LibraryElement library = await _resolveLibrary('''
          abstract class PlainFactory {}
        ''');

        final ClassElement? classElement = library.getClass('PlainFactory');
        expect(classElement, isNotNull);
        expect(assistedFactoryChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('provisionListenerChecker', () {
      test('matches @provisionListener annotation on a method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            @provisionListener
            ProvisionListener<Object> provideListener() => _MyListener();
          }

          class _MyListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }
        ''');

        final ClassElement? classElement = library.getClass('AppModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideListener');
        expect(methodElement, isNotNull);
        expect(provisionListenerChecker.hasAnnotationOf(methodElement!), isTrue);
      });

      test('does not match method without @provisionListener', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideName() => 'hello';
          }
        ''');

        final ClassElement? classElement = library.getClass('AppModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideName');
        expect(methodElement, isNotNull);
        expect(provisionListenerChecker.hasAnnotationOf(methodElement!), isFalse);
      });
    });

    group('provisionListenerInterfaceChecker', () {
      test('matches a type that implements ProvisionListener', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }
        ''');

        final ClassElement? classElement = library.getClass('LoggingListener');
        expect(classElement, isNotNull);
        expect(
          provisionListenerInterfaceChecker.isAssignableFromType(classElement!.thisType),
          isTrue,
        );
      });

      test('does not match a type that does not implement ProvisionListener', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PlainService {}
        ''');

        final ClassElement? classElement = library.getClass('PlainService');
        expect(classElement, isNotNull);
        expect(
          provisionListenerInterfaceChecker.isAssignableFromType(classElement!.thisType),
          isFalse,
        );
      });
    });

    group('package safety', () {
      test('componentChecker rejects same-named annotation from wrong package', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Component {
            const Component._();
          }
          const component = Component._();

          @component
          abstract class FakeShop {}
        ''');

        final ClassElement? classElement = library.getClass('FakeShop');
        expect(classElement, isNotNull);
        expect(componentChecker.hasAnnotationOf(classElement!), isFalse);
      });

      test('injectChecker rejects same-named annotation from wrong package', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Inject {
            const Inject._();
          }
          const inject = Inject._();

          @inject
          class FakeService {}
        ''');

        final ClassElement? classElement = library.getClass('FakeService');
        expect(classElement, isNotNull);
        expect(injectChecker.hasAnnotationOf(classElement!), isFalse);
      });

      test('singletonChecker rejects same-named annotation from wrong package', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Singleton {
            const Singleton._();
          }
          const singleton = Singleton._();

          @singleton
          class FakeService {}
        ''');

        final ClassElement? classElement = library.getClass('FakeService');
        expect(classElement, isNotNull);
        expect(singletonChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('cross-isolation', () {
      test('moduleChecker does not match @component-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @component
          abstract class CoffeeShop {}
        ''');

        final ClassElement? classElement = library.getClass('CoffeeShop');
        expect(classElement, isNotNull);
        expect(moduleChecker.hasAnnotationOf(classElement!), isFalse);
      });

      test('injectChecker does not match @module-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class CoffeeModule {}
        ''');

        final ClassElement? classElement = library.getClass('CoffeeModule');
        expect(classElement, isNotNull);
        expect(injectChecker.hasAnnotationOf(classElement!), isFalse);
      });

      test('singletonChecker does not match @component-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @component
          abstract class CoffeeShop {}
        ''');

        final ClassElement? classElement = library.getClass('CoffeeShop');
        expect(classElement, isNotNull);
        expect(singletonChecker.hasAnnotationOf(classElement!), isFalse);
      });

      test('providesChecker does not match @asynchronous-only method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class AsyncOnlyModule {
            @asynchronous
            Future<String> provideApiKey() async => 'key-123';
          }
        ''');

        final ClassElement? classElement = library.getClass('AsyncOnlyModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideApiKey');
        expect(methodElement, isNotNull);
        expect(providesChecker.hasAnnotationOf(methodElement!), isFalse);
      });

      test('qualifierChecker does not match @provides-only method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class ConfigModule {
            @provides
            String provideApiKey() => 'secret';
          }
        ''');

        final ClassElement? classElement = library.getClass('ConfigModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideApiKey');
        expect(methodElement, isNotNull);
        expect(qualifierChecker.hasAnnotationOf(methodElement!), isFalse);
      });

      test('assistedInjectChecker does not match @inject-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class SimpleService {}
        ''');

        final ClassElement? classElement = library.getClass('SimpleService');
        expect(classElement, isNotNull);
        expect(assistedInjectChecker.hasAnnotationOf(classElement!), isFalse);
      });

      test('assistedFactoryChecker does not match @component-annotated class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @component
          abstract class CoffeeShop {}
        ''');

        final ClassElement? classElement = library.getClass('CoffeeShop');
        expect(classElement, isNotNull);
        expect(assistedFactoryChecker.hasAnnotationOf(classElement!), isFalse);
      });
    });

    group('multiple annotations on same element', () {
      test('detects @inject and @singleton on the same class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          @singleton
          class SingletonService {}
        ''');

        final ClassElement? classElement = library.getClass('SingletonService');
        expect(classElement, isNotNull);
        expect(injectChecker.hasAnnotationOf(classElement!), isTrue);
        expect(singletonChecker.hasAnnotationOf(classElement), isTrue);
        expect(componentChecker.hasAnnotationOf(classElement), isFalse);
      });

      test('detects @provides and @asynchronous on the same method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AsyncModule {
            @provides
            @asynchronous
            Future<int> provideCount() async => 42;
          }
        ''');

        final ClassElement? classElement = library.getClass('AsyncModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideCount');
        expect(methodElement, isNotNull);
        expect(providesChecker.hasAnnotationOf(methodElement!), isTrue);
        expect(asynchronousChecker.hasAnnotationOf(methodElement), isTrue);
      });

      test('detects @provides and @Qualifier on the same method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const apiKey = Qualifier(#apiKey);

          @module
          class ConfigModule {
            @provides
            @apiKey
            String provideApiKey() => 'secret';
          }
        ''');

        final ClassElement? classElement = library.getClass('ConfigModule');
        expect(classElement, isNotNull);
        final MethodElement? methodElement = classElement!.getMethod('provideApiKey');
        expect(methodElement, isNotNull);
        expect(providesChecker.hasAnnotationOf(methodElement!), isTrue);
        expect(qualifierChecker.hasAnnotationOf(methodElement), isTrue);
        expect(singletonChecker.hasAnnotationOf(methodElement), isFalse);
      });
    });
  });
}
