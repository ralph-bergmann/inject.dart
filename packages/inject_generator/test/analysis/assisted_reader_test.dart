import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/assisted_reader.dart';
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
  late AssistedReader assistedReader;

  setUp(() {
    reporter = DiagnosticReporter();
    assistedReader = AssistedReader(reporter: reporter);
  });

  group('AssistedReader', () {
    group('readAssistedInject', () {
      test('partitions injected and assisted parameters', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeService {}

          class MyService {
            @assistedInject
            MyService(@assisted String name, CoffeeService coffee);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.key, isA<BindingKey>());
        expect(result.key.debugLabel, 'MyService');
        expect(result.assistedParameters, hasLength(1));
        expect(result.assistedParameters[0].type.element?.name, 'String');
        expect(result.injectedDependencies, hasLength(1));
        expect(result.injectedDependencies[0].type.element?.name, 'CoffeeService');
        expect(reporter.hasErrors, isFalse);
      });

      test('handles all parameters being assisted', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Widget {
            @assistedInject
            Widget(@assisted String title, @assisted int count);
          }
        ''');

        final ClassElement classElement = library.getClass('Widget')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.assistedParameters, hasLength(2));
        expect(result.injectedDependencies, isEmpty);
      });

      test('emits error when no @assisted parameters exist', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Dep {}

          class NoAssisted {
            @assistedInject
            NoAssisted(Dep dep);
          }
        ''');

        final ClassElement classElement = library.getClass('NoAssisted')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('has no @assisted parameters'));
      });

      test('reads qualifier on injected parameter', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);

          class MyService {
            @assistedInject
            MyService(@brandName String brand, @assisted int count);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.injectedDependencies, hasLength(1));
        expect(result.injectedDependencies[0].qualifier, 'brandName');
        expect(result.assistedParameters, hasLength(1));
        expect(result.assistedParameters[0].qualifier, isNull);
      });

      test('reads qualifier on assisted parameter', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const labelName = Qualifier(#labelName);

          class MyService {
            @assistedInject
            MyService(@assisted @labelName String label, int count);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.assistedParameters, hasLength(1));
        expect(result.assistedParameters[0].qualifier, 'labelName');
        expect(result.injectedDependencies, hasLength(1));
        expect(result.injectedDependencies[0].qualifier, isNull);
      });

      test('returns null for class with no @assistedInject constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class NoAnnotatedCtor {
            NoAnnotatedCtor.named(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('NoAnnotatedCtor')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isFalse);
      });

      test('detects singleton annotation on class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @singleton
          class SingletonService {
            @assistedInject
            SingletonService(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('SingletonService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.isSingleton, isTrue);
      });

      test('isSingleton is false by default', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class RegularService {
            @assistedInject
            RegularService(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('RegularService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.isSingleton, isFalse);
      });

      test('preserves parameter order', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class A {}
          class B {}

          class OrderedService {
            @assistedInject
            OrderedService(A a, @assisted String name, B b, @assisted int count);
          }
        ''');

        final ClassElement classElement = library.getClass('OrderedService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.injectedDependencies, hasLength(2));
        expect(result.injectedDependencies[0].type.element?.name, 'A');
        expect(result.injectedDependencies[1].type.element?.name, 'B');
        expect(result.assistedParameters, hasLength(2));
        expect(result.assistedParameters[0].type.element?.name, 'String');
        expect(result.assistedParameters[1].type.element?.name, 'int');
      });

      test('returns constructor element', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.constructor, isA<ConstructorElement>());
        expect(result.constructor.name, 'new');
        expect(result.constructorName, isNull);
      });

      test('reads named constructor with @assistedInject', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService.create(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNotNull);
        expect(result!.constructor.name, 'create');
        expect(result.constructorName, 'create');
        expect(result.assistedParameters, hasLength(1));
        expect(result.assistedParameters[0].type.element?.name, 'String');
      });

      test('emits error for multiple @assistedInject constructors', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class TwoCtor {
            @assistedInject
            TwoCtor(@assisted String a);

            @assistedInject
            TwoCtor.other(@assisted int b);
          }
        ''');

        final ClassElement classElement = library.getClass('TwoCtor')!;
        final AssistedInjectData? result = assistedReader.readAssistedInject(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(
          reporter.messages.first.message,
          contains('require unique @Qualifier annotations'),
        );
      });
    });

    group('readAssistedFactory', () {
      test('reads valid factory with matching parameters', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name, @assisted int count);
          }

          @assistedFactory
          abstract class MyServiceFactory {
            MyService create(String name, int count);
          }
        ''');

        final ClassElement classElement = library.getClass('MyServiceFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.factoryElement, classElement);
        expect(result.createMethod.name, 'create');
        expect(result.targetType.element?.name, 'MyService');
        expect(result.assistedParameters, hasLength(2));
        expect(result.assistedParameters[0].type.element?.name, 'String');
        expect(result.assistedParameters[1].type.element?.name, 'int');
        expect(reporter.hasErrors, isFalse);
      });

      test('emits error for non-abstract class', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }

          @assistedFactory
          class NotAbstractFactory {
            MyService create(String name) => throw UnimplementedError();
          }
        ''');

        final ClassElement classElement = library.getClass('NotAbstractFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('is not abstract'));
      });

      test('emits error for factory with no abstract methods', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @assistedFactory
          abstract class EmptyFactory {}
        ''');

        final ClassElement classElement = library.getClass('EmptyFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('has no abstract method'));
      });

      test('emits error for factory with multiple abstract methods', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class A {}
          class B {}

          @assistedFactory
          abstract class TooManyMethods {
            A createA(String name);
            B createB(int count);
          }
        ''');

        final ClassElement classElement = library.getClass('TooManyMethods')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('2 abstract methods'));
      });

      test('extracts return type from factory method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Widget {
            @assistedInject
            Widget(@assisted String title);
          }

          @assistedFactory
          abstract class WidgetFactory {
            Widget build(String title);
          }
        ''');

        final ClassElement classElement = library.getClass('WidgetFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.targetType.element?.name, 'Widget');
      });

      test('reads qualifier on factory method parameter', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const labelName = Qualifier(#labelName);

          class MyService {
            @assistedInject
            MyService(@assisted @labelName String label);
          }

          @assistedFactory
          abstract class MyServiceFactory {
            MyService create(@labelName String label);
          }
        ''');

        final ClassElement classElement = library.getClass('MyServiceFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.assistedParameters, hasLength(1));
        expect(result.assistedParameters[0].qualifier, 'labelName');
      });

      test('accepts named factory parameters matched by name instead of declaration order', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Greeting {
            @assistedInject
            Greeting({@assisted required int count, @assisted required String name});
          }

          @assistedFactory
          abstract class GreetingFactory {
            Greeting create({required String name, required int count});
          }
        ''');

        final ClassElement classElement = library.getClass('GreetingFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(reporter.hasErrors, isFalse);
      });

      test('emits error when return type is not an @assistedInject target', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class NotAssisted {}

          @assistedFactory
          abstract class BadFactory {
            NotAssisted create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('BadFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('has no @assistedInject constructor'));
      });

      test('emits error when return type is void', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @assistedFactory
          abstract class VoidFactory {
            void create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('VoidFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('is not a class type'));
      });

      test('reads factory targeting named constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService.create(@assisted String name);
          }

          @assistedFactory
          abstract class MyServiceFactory {
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyServiceFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.targetType.element?.name, 'MyService');
        expect(result.assistedParameters, hasLength(1));
        expect(reporter.hasErrors, isFalse);
      });

      test('emits error when factory parameter count mismatches target', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name, @assisted int count);
          }

          @assistedFactory
          abstract class WrongCountFactory {
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('WrongCountFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('1 parameter(s) but the target constructor has 2'));
      });

      test('emits error when factory parameter type mismatches target', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }

          @assistedFactory
          abstract class WrongTypeFactory {
            MyService create(int name);
          }
        ''');

        final ClassElement classElement = library.getClass('WrongTypeFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains("has type 'int'"));
      });
    });

    group('readAssistedInjects (plural)', () {
      test('returns single entry for class with one @assistedInject constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final List<AssistedInjectData> results = assistedReader.readAssistedInjects(classElement);

        expect(results, hasLength(1));
        expect(results.first.key.debugLabel, 'MyService');
        expect(results.first.constructorName, isNull);
        expect(reporter.hasErrors, isFalse);
      });

      test('returns multiple entries for class with qualified @assistedInject constructors', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @Qualifier(#quick)
            @assistedInject
            MyService(@assisted String name);

            @Qualifier(#slow)
            @assistedInject
            MyService.detailed(@assisted String name, @assisted int timeout);
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final List<AssistedInjectData> results = assistedReader.readAssistedInjects(classElement);

        expect(results, hasLength(2));
        expect(results[0].key.qualifier, 'quick');
        expect(results[0].constructorName, isNull);
        expect(results[0].assistedParameters, hasLength(1));
        expect(results[1].key.qualifier, 'slow');
        expect(results[1].constructorName, 'detailed');
        expect(results[1].assistedParameters, hasLength(2));
        expect(reporter.hasErrors, isFalse);
      });

      test('emits error when multiple constructors lack @Qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class TwoCtor {
            @assistedInject
            TwoCtor(@assisted String a);

            @assistedInject
            TwoCtor.other(@assisted int b);
          }
        ''');

        final ClassElement classElement = library.getClass('TwoCtor')!;
        final List<AssistedInjectData> results = assistedReader.readAssistedInjects(classElement);

        expect(results, isEmpty);
        expect(reporter.hasErrors, isTrue);
        expect(
          reporter.messages.first.message,
          contains('require unique @Qualifier annotations'),
        );
      });

      test('emits error when multiple constructors have duplicate @Qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class DupQual {
            @Qualifier(#same)
            @assistedInject
            DupQual(@assisted String a);

            @Qualifier(#same)
            @assistedInject
            DupQual.other(@assisted int b);
          }
        ''');

        final ClassElement classElement = library.getClass('DupQual')!;
        final List<AssistedInjectData> results = assistedReader.readAssistedInjects(classElement);

        expect(results, isEmpty);
        expect(reporter.hasErrors, isTrue);
        expect(
          reporter.messages.first.message,
          contains('Duplicate @Qualifier'),
        );
      });

      test('returns empty list for class without @assistedInject', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class PlainClass {
            PlainClass(String a);
          }
        ''');

        final ClassElement classElement = library.getClass('PlainClass')!;
        final List<AssistedInjectData> results = assistedReader.readAssistedInjects(classElement);

        expect(results, isEmpty);
        expect(reporter.hasErrors, isFalse);
      });

      test('emits error when one of multiple constructors misses @Qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MixedQual {
            @Qualifier(#named)
            @assistedInject
            MixedQual(@assisted String a);

            @assistedInject
            MixedQual.other(@assisted int b);
          }
        ''');

        final ClassElement classElement = library.getClass('MixedQual')!;
        final List<AssistedInjectData> results = assistedReader.readAssistedInjects(classElement);

        expect(results, isEmpty);
        expect(reporter.hasErrors, isTrue);
        expect(
          reporter.messages.first.message,
          contains('require unique @Qualifier annotations'),
        );
      });
    });

    group('readAssistedFactory with qualifier', () {
      test('selects constructor matching factory method qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @Qualifier(#quick)
            @assistedInject
            MyService(@assisted String name);

            @Qualifier(#slow)
            @assistedInject
            MyService.detailed(@assisted String name, @assisted int timeout);
          }

          @assistedFactory
          abstract class QuickFactory {
            @Qualifier(#quick)
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('QuickFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.targetQualifier, 'quick');
        expect(result.assistedParameters, hasLength(1));
        expect(reporter.hasErrors, isFalse);
      });

      test('selects second constructor matching factory method qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @Qualifier(#quick)
            @assistedInject
            MyService(@assisted String name);

            @Qualifier(#slow)
            @assistedInject
            MyService.detailed(@assisted String name, @assisted int timeout);
          }

          @assistedFactory
          abstract class SlowFactory {
            @Qualifier(#slow)
            MyService create(String name, int timeout);
          }
        ''');

        final ClassElement classElement = library.getClass('SlowFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.targetQualifier, 'slow');
        expect(result.assistedParameters, hasLength(2));
        expect(reporter.hasErrors, isFalse);
      });

      test('emits error when qualifier does not match any constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @Qualifier(#quick)
            @assistedInject
            MyService(@assisted String name);
          }

          @assistedFactory
          abstract class WrongQualFactory {
            @Qualifier(#nonexistent)
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('WrongQualFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(
          reporter.messages.first.message,
          contains("qualifier 'nonexistent'"),
        );
      });

      test('emits error when no qualifier but multiple @assistedInject constructors', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @Qualifier(#quick)
            @assistedInject
            MyService(@assisted String name);

            @Qualifier(#slow)
            @assistedInject
            MyService.detailed(@assisted String name, @assisted int timeout);
          }

          @assistedFactory
          abstract class AmbiguousFactory {
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('AmbiguousFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(
          reporter.messages.first.message,
          contains('multiple @assistedInject constructors but no @Qualifier'),
        );
      });

      test('factory without qualifier works for single @assistedInject constructor', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class MyService {
            @assistedInject
            MyService(@assisted String name);
          }

          @assistedFactory
          abstract class SimpleFactory {
            MyService create(String name);
          }
        ''');

        final ClassElement classElement = library.getClass('SimpleFactory')!;
        final AssistedFactoryData? result = assistedReader.readAssistedFactory(classElement);

        expect(result, isNotNull);
        expect(result!.targetQualifier, isNull);
        expect(result.assistedParameters, hasLength(1));
        expect(reporter.hasErrors, isFalse);
      });
    });
  });
}
