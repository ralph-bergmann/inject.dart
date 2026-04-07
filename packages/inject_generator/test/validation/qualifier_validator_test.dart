import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:inject_generator/src/validation/qualifier_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void _validateQualifiers({
  required DiagnosticReporter reporter,
  required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
}) {
  final result = BindingResolver(reporter: reporter).resolve(modules: modules, injectables: []);

  QualifierValidator(reporter: reporter).validate(
    bindingMap: result.bindingMap,
    duplicateBindings: result.duplicateBindings,
  );
}

void main() {
  late DiagnosticReporter reporter;

  setUp(() {
    reporter = DiagnosticReporter();
  });

  group('QualifierValidator', () {
    group('validate', () {
      test('allows different qualifiers for the same type', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const baseUri = Qualifier(#baseUri);
          const apiKey = Qualifier(#apiKey);

          @module
          class AppModule {
            @provides
            @baseUri
            String provideBaseUri() => 'https://example.com';

            @provides
            @apiKey
            String provideApiKey() => 'secret';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('reports error for duplicate binding with same qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const baseUri = Qualifier(#baseUri);

          @module
          class AppModule {
            @provides
            @baseUri
            String provideBaseUri() => 'https://example.com';

            @provides
            @baseUri
            String provideUrl() => 'https://other.com';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> errors = reporter.messages.where(
          (m) => m.message.contains('Duplicate binding'),
        );
        expect(errors, hasLength(1));
        expect(errors.first.message, contains('AppModule.provideBaseUri'));
        expect(errors.first.message, contains('AppModule.provideUrl'));
      });

      test('reports error for duplicate unqualified binding', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideGreeting() => 'hello';

            @provides
            String provideOtherGreeting() => 'hi';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> errors = reporter.messages.where(
          (m) => m.message.contains('Duplicate binding'),
        );
        expect(errors, hasLength(1));
        expect(errors.first.message, contains('AppModule.provideGreeting'));
        expect(errors.first.message, contains('AppModule.provideOtherGreeting'));
      });

      test('allows one qualified and one unqualified binding for same type', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const label = Qualifier(#label);

          @module
          class AppModule {
            @provides
            @label
            String provideLabel() => 'tagged';

            @provides
            String provideDefault() => 'default';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('reports error listing all three origins for triple duplicate', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const tag = Qualifier(#tag);

          @module
          class AppModule {
            @provides
            @tag
            String provideFirst() => 'a';

            @provides
            @tag
            String provideSecond() => 'b';

            @provides
            @tag
            String provideThird() => 'c';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> errors = reporter.messages.where(
          (m) => m.message.contains('Duplicate binding'),
        );
        expect(errors, hasLength(1));
        expect(errors.first.message, contains('AppModule.provideFirst'));
        expect(errors.first.message, contains('AppModule.provideSecond'));
        expect(errors.first.message, contains('AppModule.provideThird'));
      });

      test('does not report error for empty binding map', () async {
        final qualifierValidator = QualifierValidator(reporter: reporter);
        qualifierValidator.validate(bindingMap: {}, duplicateBindings: {});

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('includes qualifier info in diagnostic debugLabel', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const baseUri = Qualifier(#baseUri);

          @module
          class AppModule {
            @provides
            @baseUri
            String provideBaseUri() => 'https://example.com';

            @provides
            @baseUri
            String provideUrl() => 'https://other.com';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> errors = reporter.messages.where(
          (m) => m.message.contains('Duplicate binding'),
        );
        expect(errors.first.message, contains('#baseUri'));
      });

      test('includes suggestion for disambiguation', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideA() => 'a';

            @provides
            String provideB() => 'b';
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> errors = reporter.messages.where(
          (m) => m.message.contains('Duplicate binding'),
        );
        expect(errors.first.suggestion, contains('@Qualifier'));
      });

      test('allows different types with same qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const primary = Qualifier(#primary);

          @module
          class AppModule {
            @provides
            @primary
            String provideLabel() => 'main';

            @provides
            @primary
            int provideCount() => 42;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateQualifiers(reporter: reporter, modules: [(moduleClass: moduleClass, moduleData: moduleData)]);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });
    });
  });
}
