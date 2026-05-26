import 'package:analyzer/dart/element/element.dart';

import '../logging/diagnostic_reporter.dart';

/// Validates symbol visibility against the target output type.
///
/// Different output types have different visibility constraints:
/// - `.inject.dart` (separate library): only public, importable symbols
/// - `.factory.dart` (part file): private symbols only from same source library
class VisibilityValidator {
  /// Creates a [VisibilityValidator] reporting through [reporter].
  VisibilityValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  /// Validates that all [elements] are public and importable for
  /// `.inject.dart` output (a separate library that cannot access
  /// private symbols).
  void validateForInjectOutput({required LibraryElement sourceLibrary, required List<Element> elements}) {
    for (final element in elements) {
      if (element.isPrivate) {
        final String category = _elementCategory(element);
        _reporter.errorForElement(
          element,
          message:
              'Private $category \'${element.name}\' cannot be referenced in '
              'generated .inject.dart output.',
          suggestion:
              'Make \'${element.name}\' public by removing the underscore '
              'prefix, or move it into a @module provider that encapsulates '
              'the private dependency.',
        );
      }
    }
  }

  /// Validates that private [elements] in `.factory.dart` output are only
  /// from the [sourceLibrary] itself.
  ///
  /// `.factory.dart` is a `part` file and can access private symbols, but
  /// only those declared in the same source library.
  void validateForFactoryOutput({required LibraryElement sourceLibrary, required List<Element> elements}) {
    for (final element in elements) {
      if (!element.isPrivate) {
        continue;
      }

      final LibraryElement? elementLibrary = element.library;
      if (elementLibrary == null) {
        continue;
      }

      if (elementLibrary != sourceLibrary) {
        final elementLibraryUri = elementLibrary.firstFragment.source.uri.toString();
        final sourceLibraryUri = sourceLibrary.firstFragment.source.uri.toString();
        final String category = _elementCategory(element);

        _reporter.errorForElement(
          element,
          message:
              'Private $category \'${element.name}\' from library '
              '\'$elementLibraryUri\' cannot be referenced in '
              'generated .factory.dart output of \'$sourceLibraryUri\'.',
          suggestion:
              'Move \'${element.name}\' into the same library as the '
              'factory, or make it public.',
        );
      }
    }
  }

  /// Returns a human-readable category name for the element.
  String _elementCategory(Element element) => switch (element) {
    ClassElement() => 'class',
    ConstructorElement() => 'constructor',
    MethodElement() => 'method',
    PropertyAccessorElement() => 'accessor',
    FormalParameterElement() => 'parameter',
    TypeAliasElement() => 'typedef',
    _ => 'symbol',
  };
}
