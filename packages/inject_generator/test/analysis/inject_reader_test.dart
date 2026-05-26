import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late InjectReader injectReader;

  setUp(() {
    reporter = DiagnosticReporter();
    injectReader = InjectReader(reporter: reporter);
  });

  group('InjectReader', () {
    group('constructor dependency extraction', () {
      test('reads @inject on unnamed constructor with parameters', () async {
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
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.key, isA<BindingKey>());
        expect(result.key.qualifier, isNull);
        expect(result.key.debugLabel, 'CoffeeMaker');
        expect(result.dependencies, hasLength(2));
        expect(result.dependencies[0].type.element?.name, 'Heater');
        expect(result.dependencies[1].type.element?.name, 'Pump');
      });

      test('reads class with no explicit constructor (implicit unnamed)', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class SimpleService {}
        ''');

        final ClassElement classElement = library.getClass('SimpleService')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.key, isA<BindingKey>());
        expect(result.key.debugLabel, 'SimpleService');
        expect(result.dependencies, isEmpty);
      });

      test('preserves parameter order', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class A {}
          class B {}
          class C {}

          class OrderedService {
            @inject
            OrderedService(A a, B b, C c);
          }
        ''');

        final ClassElement classElement = library.getClass('OrderedService')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.dependencies, hasLength(3));
        expect(result.dependencies[0].type.element?.name, 'A');
        expect(result.dependencies[1].type.element?.name, 'B');
        expect(result.dependencies[2].type.element?.name, 'C');
      });

      test('reads @Qualifier on constructor parameter', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);
          const modelName = Qualifier(#modelName);

          class CoffeeMaker {
            @inject
            CoffeeMaker(@brandName String brand, @modelName String model);
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.dependencies, hasLength(2));
        expect(result.dependencies[0].qualifier, 'brandName');
        expect(result.dependencies[1].qualifier, 'modelName');
      });

      test('uses sole named constructor when no unnamed exists', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class OnlyNamed {
            OnlyNamed.named();
          }
        ''');

        final ClassElement classElement = library.getClass('OnlyNamed')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, 'named');
      });
    });

    group('binding metadata', () {
      test('reads @singleton on class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          @singleton
          class SingletonService {}
        ''');

        final ClassElement classElement = library.getClass('SingletonService')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.key, isA<BindingKey>());
        expect(result.key.debugLabel, 'SingletonService');
        expect(result.isSingleton, isTrue);
      });

      test('reads class without binding metadata', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class PlainService {}
        ''');

        final ClassElement classElement = library.getClass('PlainService')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.isSingleton, isFalse);
      });
    });

    group('optional and named parameters', () {
      test('reads optional positional parameters', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Logger {}

          class CoffeeMaker {
            @inject
            CoffeeMaker([Logger? logger]);
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.dependencies, hasLength(1));
        expect(result.dependencies[0].parameter.isOptionalPositional, isTrue);
        expect(result.dependencies[0].type.element?.name, 'Logger');
      });

      test('reads named parameters', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}
          class Pump {}

          class CoffeeMaker {
            @inject
            CoffeeMaker({required Heater heater, Pump? pump});
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.dependencies, hasLength(2));

        expect(result.dependencies[0].parameter.isNamed, isTrue);
        expect(result.dependencies[0].parameter.isRequired, isTrue);
        expect(result.dependencies[0].type.element?.name, 'Heater');

        expect(result.dependencies[1].parameter.isNamed, isTrue);
        expect(result.dependencies[1].parameter.isRequired, isFalse);
        expect(result.dependencies[1].type.element?.name, 'Pump');
      });

      test('reads @Qualifier on named parameters', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const api = Qualifier(#api);

          class CoffeeMaker {
            @inject
            CoffeeMaker({@api required String apiKey});
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.dependencies, hasLength(1));
        expect(result.dependencies[0].parameter.isNamed, isTrue);
        expect(result.dependencies[0].qualifier, 'api');
      });
    });

    group('named constructor support', () {
      test('reads @inject on named constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          class CoffeeMaker {
            @inject
            CoffeeMaker.french(Heater heater);
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, 'french');
        expect(result.dependencies, hasLength(1));
        expect(result.dependencies[0].type.element?.name, 'Heater');
      });

      test('reads @inject on factory constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          class CoffeeMaker {
            final Heater heater;
            CoffeeMaker._(this.heater);

            @inject
            factory CoffeeMaker.create(Heater heater) = CoffeeMaker._;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, 'create');
        expect(result.dependencies, hasLength(1));
      });

      test('falls back to unnamed constructor when @inject is on class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class SimpleService {}
        ''');

        final ClassElement classElement = library.getClass('SimpleService')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, isNull);
      });

      test('constructorName is null for @inject on unnamed constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {
            @inject
            CoffeeMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, isNull);
      });

      test('errors when multiple @inject constructors without qualifiers', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {
            @inject
            CoffeeMaker();

            @inject
            CoffeeMaker.french();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('Multiple @inject constructors'));
      });

      test('singleton with named constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @singleton
          class CoffeeMaker {
            @inject
            CoffeeMaker.premium(Heater heater);
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, 'premium');
        expect(result.isSingleton, isTrue);
      });

      test('singleton with @inject on unnamed constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @singleton
          class CoffeeMaker {
            @inject
            CoffeeMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, isNull);
        expect(result.isSingleton, isTrue);
      });

      test('uses sole named constructor when class-level @inject and no unnamed', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class OnlyNamedConstructor {
            OnlyNamedConstructor.create();
          }
        ''');

        final ClassElement classElement = library.getClass('OnlyNamedConstructor')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNotNull);
        expect(result!.constructorName, 'create');
        expect(reporter.hasErrors, isFalse);
      });

      test('returns null for class-level @inject with multiple named constructors and no unnamed', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class MultipleNamed {
            MultipleNamed.first();
            MultipleNamed.second();
          }
        ''');

        final ClassElement classElement = library.getClass('MultipleNamed')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('has multiple constructors'));
      });

      test('returns null for unannotated class with sole named constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class NotInjectable {
            NotInjectable.create();
          }
        ''');

        final ClassElement classElement = library.getClass('NotInjectable')!;
        final InjectableData? result = injectReader.readInjectable(classElement);

        expect(result, isNull);
      });
    });

    group('multiple @inject constructors', () {
      test('reads two @inject constructors with distinct qualifiers', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Canvas {}

          const preview = Qualifier(#preview);
          const detail = Qualifier(#detail);

          class ProfileWidget {
            @inject
            @preview
            ProfileWidget.preview(Canvas canvas);

            @inject
            @detail
            ProfileWidget.detail(Canvas canvas);
          }
        ''');

        final ClassElement classElement = library.getClass('ProfileWidget')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(2));

        final InjectableData previewResult = results.firstWhere((r) => r.constructorName == 'preview');
        expect(previewResult.key.qualifier, 'preview');
        expect(previewResult.dependencies, hasLength(1));
        expect(previewResult.dependencies[0].type.element?.name, 'Canvas');

        final InjectableData detailResult = results.firstWhere((r) => r.constructorName == 'detail');
        expect(detailResult.key.qualifier, 'detail');
        expect(detailResult.dependencies, hasLength(1));
        expect(detailResult.dependencies[0].type.element?.name, 'Canvas');
      });

      test('errors when multiple @inject constructors have no qualifiers', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {
            @inject
            CoffeeMaker();

            @inject
            CoffeeMaker.french();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, isEmpty);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('Multiple @inject constructors'));
      });

      test('errors when multiple @inject constructors have duplicate qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const same = Qualifier(#same);

          class CoffeeMaker {
            @inject
            @same
            CoffeeMaker();

            @inject
            @same
            CoffeeMaker.french();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, isEmpty);
        expect(reporter.hasErrors, isTrue);
        expect(
          reporter.messages.first.message,
          equals("Duplicate @Qualifier on constructors of 'CoffeeMaker'."),
        );
      });

      test('single @inject constructor still returns list with one element', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          class CoffeeMaker {
            @inject
            CoffeeMaker(Heater heater);
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(1));
        expect(results.first.constructorName, isNull);
        expect(results.first.dependencies, hasLength(1));
      });

      test('class-level @inject still returns list with one element', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class CoffeeMaker {
            CoffeeMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeMaker')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(1));
        expect(results.first.constructorName, isNull);
        expect(results.first.key.qualifier, isNull);
      });

      test('per-constructor qualifier is part of BindingKey', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const fast = Qualifier(#fast);
          const slow = Qualifier(#slow);

          class Pump {
            @inject
            @fast
            Pump.turbo();

            @inject
            @slow
            Pump.manual();
          }
        ''');

        final ClassElement classElement = library.getClass('Pump')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(2));
        expect(results[0].key.qualifier, isNot(results[1].key.qualifier));
        expect(results[0].key, isNot(results[1].key));
      });

      test('singleton applies to both qualified constructors', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const preview = Qualifier(#preview);
          const detail = Qualifier(#detail);

          @singleton
          class ConfigService {
            @inject
            @preview
            ConfigService.forPreview();

            @inject
            @detail
            ConfigService.forDetail();
          }
        ''');

        final ClassElement classElement = library.getClass('ConfigService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(2));
        expect(results[0].isSingleton, isTrue);
        expect(results[1].isSingleton, isTrue);
      });
    });

    group('@asynchronous warning', () {
      test('warns when @asynchronous is on @inject class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @asynchronous
          @inject
          class AsyncService {
            AsyncService();
          }
        ''');

        final ClassElement classElement = library.getClass('AsyncService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        // Binding is still produced — warning does not block codegen.
        expect(results, hasLength(1));
        expect(results.first.key.debugLabel, 'AsyncService');

        // Warning was emitted.
        expect(reporter.warningCount, equals(1));
        expect(reporter.hasErrors, isFalse);
        expect(
          reporter.messages.first.message,
          contains("'@asynchronous' on class 'AsyncService' has no effect and is ignored"),
        );
        // Source snippet is present.
        expect(reporter.messages.first.snippet, isNotNull);
      });

      test('warns when @asynchronous is on @inject constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class AsyncService {
            @asynchronous
            @inject
            AsyncService();
          }
        ''');

        final ClassElement classElement = library.getClass('AsyncService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        // Binding is still produced — warning does not block codegen.
        expect(results, hasLength(1));
        expect(results.first.key.debugLabel, 'AsyncService');

        // Warning was emitted.
        expect(reporter.warningCount, equals(1));
        expect(reporter.hasErrors, isFalse);
        expect(
          reporter.messages.first.message,
          contains("'@asynchronous' on constructor 'AsyncService' has no effect and is ignored"),
        );
      });

      test('warns when @asynchronous is on class with @inject constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @asynchronous
          class AsyncService {
            @inject
            AsyncService();
          }
        ''');

        final ClassElement classElement = library.getClass('AsyncService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(1));
        expect(reporter.warningCount, equals(1));
        expect(reporter.hasErrors, isFalse);
        expect(
          reporter.messages.first.message,
          contains("'@asynchronous' on class 'AsyncService' has no effect and is ignored"),
        );
        // Source snippet is present.
        expect(reporter.messages.first.snippet, isNotNull);
      });

      test('warns when @inject is on class with @asynchronous constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class AsyncService {
            @asynchronous
            AsyncService();
          }
        ''');

        final ClassElement classElement = library.getClass('AsyncService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(1));
        expect(reporter.warningCount, equals(1));
        expect(reporter.hasErrors, isFalse);
        expect(
          reporter.messages.first.message,
          contains("'@asynchronous' on constructor 'AsyncService' has no effect and is ignored"),
        );
      });

      test('does not warn when @inject class has no @asynchronous', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class NormalService {
            NormalService();
          }
        ''');

        final ClassElement classElement = library.getClass('NormalService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(1));
        expect(reporter.warningCount, equals(0));
        expect(reporter.messages, isEmpty);
      });

      test('does not warn when class has @asynchronous without @inject', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @asynchronous
          class AsyncOnly {
            AsyncOnly();
          }
        ''');

        final ClassElement classElement = library.getClass('AsyncOnly')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        // No @inject — not recognized as injectable.
        expect(results, isEmpty);
        expect(reporter.warningCount, equals(0));
        expect(reporter.messages, isEmpty);
      });

      test('warns for each @asynchronous constructor individually', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MultiService {
            @inject
            @asynchronous
            @Qualifier(#first)
            MultiService();

            @inject
            @asynchronous
            @Qualifier(#second)
            MultiService.secondary();
          }
        ''');

        final ClassElement classElement = library.getClass('MultiService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(2));
        expect(reporter.warningCount, equals(2));
        expect(reporter.hasErrors, isFalse);
        expect(
          reporter.messages[0].message,
          contains("'@asynchronous' on constructor 'MultiService'"),
        );
        expect(
          reporter.messages[1].message,
          contains("'@asynchronous' on constructor 'MultiService.secondary'"),
        );
      });

      test('warns separately for class and constructor @asynchronous', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @asynchronous
          class BothService {
            @inject
            @asynchronous
            BothService();
          }
        ''');

        final ClassElement classElement = library.getClass('BothService')!;
        final List<InjectableData> results = injectReader.readInjectables(classElement);

        expect(results, hasLength(1));
        expect(reporter.warningCount, equals(2));
        expect(reporter.hasErrors, isFalse);
        expect(
          reporter.messages[0].message,
          contains("'@asynchronous' on class 'BothService'"),
        );
        expect(
          reporter.messages[1].message,
          contains("'@asynchronous' on constructor 'BothService'"),
        );
      });
    });
  });
}
