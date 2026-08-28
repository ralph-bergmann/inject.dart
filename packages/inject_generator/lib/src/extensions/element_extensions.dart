import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import '../analysis/type_checkers.dart';
import 'string_extensions.dart';

/// Analyzer helpers for source positions, import URIs, and qualifier reading.
extension ElementExt on Element {
  /// Returns this element's source position as `(filePath, lineNumber, column)`,
  /// or `('<unknown>', 0, 0)` if the source location is unavailable.
  (String filePath, int lineNumber, int column) get elementPosition {
    final LibraryFragment? libraryFragment = firstFragment.libraryFragment;
    if (libraryFragment == null) {
      return ('<unknown>', 0, 0);
    }

    final filePath = libraryFragment.source.uri.toString();
    final int offset = firstFragment.nameOffset ?? 0;
    final CharacterLocation location = libraryFragment.lineInfo.getLocation(offset);

    return (filePath, location.lineNumber, location.columnNumber);
  }

  /// Resolves the import URI for the library declaring [Element].
  ///
  /// When [sourceUri] is provided and the element is in the same package,
  /// returns a relative path (Dart convention `prefer_relative_imports`) —
  /// unless the source lives outside lib/ (test/, example/, …) while the
  /// target lives inside lib/, in which case the package URI is kept.
  /// When [sourceUri] is `null`, returns the absolute package URI.
  /// The original library URI is preserved as-is (including `/src/` paths);
  /// the generated output uses `// ignore_for_file: implementation_imports`.
  String resolvePublicUri({String? sourceUri}) {
    final String uri = library!.identifier;
    if (uri.startsWith('dart:')) {
      return uri;
    }

    // Without sourceUri, return the absolute package URI
    if (sourceUri == null) {
      return uri;
    }

    final ({String packageName, String path, String scheme})? sourceLocation = sourceUri.packageLocation();
    final ({String packageName, String path, String scheme})? targetLocation = uri.packageLocation();
    if (sourceLocation != null && targetLocation != null && sourceLocation.packageName == targetLocation.packageName) {
      if (sourceLocation.scheme == 'asset' && targetLocation.scheme == 'package') {
        // The output lives outside lib/ (test/, example/, tool/, …) while the
        // target lives inside lib/. Their paths are rooted differently
        // (package root vs. lib/), so no correct relative path can be
        // computed — keep the package URI.
        return uri;
      }

      return p.posix.relative(targetLocation.path, from: p.posix.dirname(sourceLocation.path));
    }

    return uri;
  }

  /// Returns the return type for entry-point elements (getters and methods),
  /// or `null` for unsupported element kinds.
  DartType? get entryPointReturnType => switch (this) {
    PropertyAccessorElement(:final returnType) => returnType,
    MethodElement(:final returnType) => returnType,
    _ => null,
  };

  /// Returns the name for entry-point elements (getters and methods),
  /// or `null` for unsupported element kinds.
  String? get entryPointName => switch (this) {
    PropertyAccessorElement(:final name) => name,
    MethodElement(:final name) => name,
    _ => null,
  };

  /// Reads the `@Qualifier(#name)` annotation from this element and returns
  /// the symbol name as a [String], or `null` if not present.
  String? readQualifier() {
    final DartObject? annotation = qualifierChecker.firstAnnotationOf(this);
    if (annotation == null) {
      return null;
    }
    return annotation.getField('name')?.toSymbolValue();
  }
}
