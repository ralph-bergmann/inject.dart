import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/visibility_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late VisibilityValidator validator;

  setUp(() {
    reporter = DiagnosticReporter();
    validator = VisibilityValidator(reporter: reporter);
  });

  group('VisibilityValidator', () {
    group('validateForInjectOutput', () {
      test('reports error for private class in inject output', () async {
        final LibraryElement library = await _resolveLibrary('''
          class _PrivateService {}
        ''');

        final ClassElement classElement = library.getClass('_PrivateService')!;

        validator.validateForInjectOutput(sourceLibrary: library, elements: [classElement]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        expect(reporter.messages.first.message, contains('Private class'));
        expect(reporter.messages.first.message, contains('_PrivateService'));
        expect(reporter.messages.first.line, equals(1));
      });

      test('reports error for private constructor in inject output', () async {
        final LibraryElement library = await _resolveLibrary('''
          class MyService {
            MyService._internal();
          }
        ''');

        final ClassElement classElement = library.getClass('MyService')!;
        final ConstructorElement constructor = classElement.constructors.firstWhere((c) => c.name == '_internal');

        validator.validateForInjectOutput(sourceLibrary: library, elements: [constructor]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        expect(reporter.messages.first.message, contains('Private constructor'));
      });

      test('reports actual source line numbers', () async {
        final LibraryElement library = await _resolveLibrary('''


          class _PrivateService {}
        ''');

        final ClassElement classElement = library.getClass('_PrivateService')!;

        validator.validateForInjectOutput(sourceLibrary: library, elements: [classElement]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.line, equals(3));
      });

      test('allows public class from another library', () async {
        final LibraryElement library = await _resolveLibrary('''
          class PublicService {}
        ''');

        final ClassElement classElement = library.getClass('PublicService')!;

        validator.validateForInjectOutput(sourceLibrary: library, elements: [classElement]);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });
    });

    group('validateForFactoryOutput', () {
      test('allows private class in same library for factory output', () async {
        final LibraryElement library = await _resolveLibrary('''
          class _PrivateService {}
        ''');

        final ClassElement classElement = library.getClass('_PrivateService')!;

        validator.validateForFactoryOutput(sourceLibrary: library, elements: [classElement]);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('reports error for private class from other library in factory output', () async {
        // Resolve the private class in its own library
        final LibraryElement otherLibrary = await _resolveLibrary('''
          class _PrivateFromOther {}
        ''');

        // Resolve a separate library as the "source" / factory host.
        // Different resolveSource sessions produce distinct LibraryElement
        // instances, so elementLibrary != sourceLibrary.
        final LibraryElement sourceLibrary = await _resolveLibrary('''
          class FactoryHost {}
        ''');

        final ClassElement privateClass = otherLibrary.getClass('_PrivateFromOther')!;

        validator.validateForFactoryOutput(sourceLibrary: sourceLibrary, elements: [privateClass]);

        expect(reporter.hasErrors, isTrue);
        expect(reporter.errorCount, equals(1));
        expect(reporter.messages.first.message, contains('Private class'));
        expect(reporter.messages.first.message, contains('_PrivateFromOther'));
      });
    });
  });
}
