import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:inject_generator/src/validation/module_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

/// Minimal [ModuleData] with no providers — sufficient for name-only checks.
const ModuleData _emptyModuleData = (providers: <ProviderDescriptor>[], hasDefaultConstructor: true);

void main() {
  late DiagnosticReporter reporter;
  late ModuleValidator validator;

  setUp(() {
    reporter = DiagnosticReporter();
    validator = ModuleValidator(reporter: reporter);
  });

  group('ModuleValidator', () {
    // -----------------------------------------------------------------------
    // Private module class
    // -----------------------------------------------------------------------
    group('validateModules — private class', () {
      test('reports error for private module class name', () async {
        final LibraryElement library = await _resolveLibrary('class _AppModule {}');
        final ClassElement classElement = library.getClass('_AppModule')!;

        validator.validateModules([(moduleClass: classElement, moduleData: _emptyModuleData)]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        expect(reporter.messages.first.message, contains('must be public'));
        expect(reporter.messages.first.message, contains('_AppModule'));
      });

      test('does not report error for public module class', () async {
        final LibraryElement library = await _resolveLibrary('class AppModule {}');
        final ClassElement classElement = library.getClass('AppModule')!;

        validator.validateModules([(moduleClass: classElement, moduleData: _emptyModuleData)]);

        expect(reporter.hasErrors, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Dart reserved word as module class name
    // -----------------------------------------------------------------------
    group('validateModules — reserved word class name', () {
      test('reports error when module class name is a Dart reserved word (Default)', () async {
        final LibraryElement library = await _resolveLibrary('class Default {}');
        final ClassElement classElement = library.getClass('Default')!;

        validator.validateModules([(moduleClass: classElement, moduleData: _emptyModuleData)]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        expect(reporter.messages.first.message, contains('reserved word'));
        expect(reporter.messages.first.message, contains('Default'));
      });

      test('reports error when module class name is a built-in identifier (Get)', () async {
        final LibraryElement library = await _resolveLibrary('class Get {}');
        final ClassElement classElement = library.getClass('Get')!;

        validator.validateModules([(moduleClass: classElement, moduleData: _emptyModuleData)]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('reserved word'));
        expect(reporter.messages.first.message, contains('Get'));
      });

      test('does not report error for non-reserved module class name', () async {
        final LibraryElement library = await _resolveLibrary('class AppModule {}');
        final ClassElement classElement = library.getClass('AppModule')!;

        validator.validateModules([(moduleClass: classElement, moduleData: _emptyModuleData)]);

        expect(reporter.hasErrors, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Dart reserved word as injectable type name
    // -----------------------------------------------------------------------
    group('validateInjectables — reserved word class name', () {
      test('reports error when injectable class name is a Dart reserved word (Default)', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Default {
            Default();
          }
        ''');
        final ClassElement classElement = library.getClass('Default')!;
        final ConstructorElement constructor = classElement.constructors.first;
        final BindingKey key = BindingKey.fromDartType(classElement.thisType)!;
        final InjectableData injectable = (
          key: key,
          constructor: constructor,
          constructorName: null,
          dependencies: const [],
          isSingleton: false,
        );

        validator.validateInjectables([(classElement: classElement, injectable: injectable)]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        expect(reporter.messages.first.message, contains('reserved word'));
        expect(reporter.messages.first.message, contains('Default'));
      });

      test('does not report error for non-reserved injectable class name', () async {
        final LibraryElement library = await _resolveLibrary('''
          class MyService {
            MyService();
          }
        ''');
        final ClassElement classElement = library.getClass('MyService')!;
        final ConstructorElement constructor = classElement.constructors.first;
        final BindingKey key = BindingKey.fromDartType(classElement.thisType)!;
        final InjectableData injectable = (
          key: key,
          constructor: constructor,
          constructorName: null,
          dependencies: const [],
          isSingleton: false,
        );

        validator.validateInjectables([(classElement: classElement, injectable: injectable)]);

        expect(reporter.hasErrors, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Qualified + unqualified provider for same type — warning only
    // -----------------------------------------------------------------------
    group('validateModules — qualified/unqualified conflict', () {
      test('no warning when module has only one provider per type', () async {
        final LibraryElement library = await _resolveLibrary('''
          class AppModule {
            String provideName() => 'test';
          }
        ''');
        final ClassElement classElement = library.getClass('AppModule')!;
        final MethodElement method = classElement.methods.first;
        final BindingKey key = BindingKey.fromDartType(method.returnType)!;

        final ModuleData moduleData = (
          providers: [
            (
              key: key,
              method: method,
              returnType: method.returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: null,
              ),
            ),
          ],
          hasDefaultConstructor: true,
        );

        validator.validateModules([(moduleClass: classElement, moduleData: moduleData)]);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.warningCount, equals(0));
      });

      test('emits warning when module has both qualified and unqualified provider for same type', () async {
        final LibraryElement library = await _resolveLibrary('''
          class AppModule {
            String provideName() => 'name';
            String provideQualifiedName() => 'qualified name';
          }
        ''');
        final ClassElement classElement = library.getClass('AppModule')!;
        final List<MethodElement> methods = classElement.methods;
        final MethodElement method1 = methods[0];
        final MethodElement method2 = methods[1];
        final BindingKey unqualifiedKey = BindingKey.fromDartType(method1.returnType)!;
        final BindingKey qualifiedKey = BindingKey.fromDartType(method2.returnType, qualifier: 'branded')!;

        final ModuleData moduleData = (
          providers: [
            (
              key: unqualifiedKey,
              method: method1,
              returnType: method1.returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: null,
              ),
            ),
            (
              key: qualifiedKey,
              method: method2,
              returnType: method2.returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: 'branded',
              ),
            ),
          ],
          hasDefaultConstructor: true,
        );

        validator.validateModules([(moduleClass: classElement, moduleData: moduleData)]);

        expect(reporter.hasErrors, isFalse, reason: 'Qualified/unqualified conflict must emit warning, not error');
        expect(reporter.warningCount, equals(1));
        expect(reporter.messages.first.message, contains('qualified'));
        expect(reporter.messages.first.message, contains('unqualified'));
        expect(reporter.messages.first.message, contains('AppModule'));
      });

      test('aggregates multiple qualified entries into a single warning', () async {
        final LibraryElement library = await _resolveLibrary('''
          class AppModule {
            String provideDefault() => 'default';
            String provideA() => 'a';
            String provideB() => 'b';
          }
        ''');
        final ClassElement classElement = library.getClass('AppModule')!;
        final List<MethodElement> methods = classElement.methods;
        final BindingKey unqualifiedKey = BindingKey.fromDartType(methods[0].returnType)!;
        final BindingKey qualifiedKeyA = BindingKey.fromDartType(methods[1].returnType, qualifier: 'a')!;
        final BindingKey qualifiedKeyB = BindingKey.fromDartType(methods[2].returnType, qualifier: 'b')!;

        final ModuleData moduleData = (
          providers: [
            (
              key: unqualifiedKey,
              method: methods[0],
              returnType: methods[0].returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: null,
              ),
            ),
            (
              key: qualifiedKeyA,
              method: methods[1],
              returnType: methods[1].returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: 'a',
              ),
            ),
            (
              key: qualifiedKeyB,
              method: methods[2],
              returnType: methods[2].returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: 'b',
              ),
            ),
          ],
          hasDefaultConstructor: true,
        );

        validator.validateModules([(moduleClass: classElement, moduleData: moduleData)]);

        expect(reporter.warningCount, equals(1), reason: 'Conflict cluster must produce exactly one aggregated warning');
        expect(reporter.messages.first.message, contains('#a'));
        expect(reporter.messages.first.message, contains('#b'));
        expect(reporter.messages.first.message, contains('unqualified'));
      });

      test('no warning when module has two qualified providers of same type', () async {
        final LibraryElement library = await _resolveLibrary('''
          class AppModule {
            String provideA() => 'a';
            String provideB() => 'b';
          }
        ''');
        final ClassElement classElement = library.getClass('AppModule')!;
        final List<MethodElement> methods = classElement.methods;
        final BindingKey key1 = BindingKey.fromDartType(methods[0].returnType, qualifier: 'q1')!;
        final BindingKey key2 = BindingKey.fromDartType(methods[1].returnType, qualifier: 'q2')!;

        final ModuleData moduleData = (
          providers: [
            (
              key: key1,
              method: methods[0],
              returnType: methods[0].returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: 'q1',
              ),
            ),
            (
              key: key2,
              method: methods[1],
              returnType: methods[1].returnType,
              dependencies: const [],
              metadata: (
                isSingleton: false,
                isAsynchronous: false,
                isProvisionListener: false,
                listenerTypeArgument: null,
                qualifier: 'q2',
              ),
            ),
          ],
          hasDefaultConstructor: true,
        );

        validator.validateModules([(moduleClass: classElement, moduleData: moduleData)]);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.warningCount, equals(0));
      });
    });
  });
}
