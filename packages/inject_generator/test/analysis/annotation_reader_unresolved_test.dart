import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
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

  group('AnnotationReader unresolved annotation guard', () {
    // Simulation approach: A `final` (non-const) variable used as metadata
    // creates annotation metadata the analyzer can parse but whose
    // computeConstantValue() returns null, triggering
    // UnresolvedAnnotationException in TypeChecker.hasAnnotationOf().
    test('isComponent returns false and emits warning for unresolvable annotation', () async {
      final LibraryElement library = await _resolveLibrary('''
        final broken = Object();

        @broken
        class BrokenAnnotation {}
      ''');

      final ClassElement classElement = library.getClass('BrokenAnnotation')!;
      expect(reader.isComponent(classElement), isFalse);
      expect(reporter.messages, hasLength(1));
      expect(reporter.messages.first.severity, DiagnosticSeverity.warning);
      expect(reporter.messages.first.message, contains('BrokenAnnotation'));
    });

    test('isComponent returns true when valid @component coexists with unresolvable annotation', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        final broken = Object();

        @broken
        @component
        class MixedAnnotation {}
      ''');

      final ClassElement classElement = library.getClass('MixedAnnotation')!;
      expect(reader.isComponent(classElement), isTrue);
      expect(reporter.messages, hasLength(1));
      expect(reporter.messages.first.severity, DiagnosticSeverity.warning);
    });
  });
}
