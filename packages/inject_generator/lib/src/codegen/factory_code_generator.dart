import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/annotation_reader.dart';
import '../analysis/assisted_reader.dart';
import '../analysis/module_reader.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/visibility_validator.dart';
import 'emit_and_format.dart';
import 'factory_generator.dart';

/// Orchestrates code generation for a single `.factory.dart` output file.
///
/// Discovers `@assistedInject` and `@assistedFactory` classes in a library,
/// delegates to [FactoryGenerator], and produces the final formatted
/// Dart source for the `PartBuilder` output.
class FactoryCodeGenerator {
  final _factoryGen = FactoryGenerator();

  /// Generates the `.factory.dart` body content for the given [library].
  ///
  /// Returns the formatted source string, or `null` if no valid
  /// assisted factory pairs were found or validation fails.
  String? generate({required LibraryElement library, required AnnotationReader reader}) {
    // Collect @assistedInject data
    final List<ClassElement> assistedInjectClasses = library.classes.where(reader.isAssistedInject).toList();

    final injectDataList = <AssistedInjectData>[];
    for (final classElement in assistedInjectClasses) {
      injectDataList.addAll(reader.readAssistedInjects(classElement));
    }

    if (injectDataList.isEmpty) {
      return null;
    }

    // Collect @assistedFactory data
    final List<ClassElement> assistedFactoryClasses = library.classes.where(reader.isAssistedFactory).toList();

    final factoryDataList = <AssistedFactoryData>[];
    for (final factoryClass in assistedFactoryClasses) {
      final AssistedFactoryData? data = reader.readAssistedFactory(factoryClass);
      if (data != null) {
        factoryDataList.add(data);
      }
    }

    // Visibility validation: collect elements referenced in generated code
    final referencedElements = <Element>[];
    for (final data in injectDataList) {
      for (final ParameterDependency dep in data.injectedDependencies) {
        if (dep.type case InterfaceType(:final element)) {
          referencedElements.add(element);
        }
      }
    }
    for (final data in factoryDataList) {
      referencedElements.add(data.factoryElement);
    }

    VisibilityValidator(
      reporter: reader.reporter,
    ).validateForFactoryOutput(sourceLibrary: library, elements: referencedElements);

    if (reader.reporter.hasErrors) {
      return null;
    }

    // Identify which @assistedInject classes already have an explicit
    // @assistedFactory matched against them; the rest get synthesized
    // abstract factories in this part file.
    final matchedInjectData = <AssistedInjectData>{};
    for (final factoryData in factoryDataList) {
      final AssistedInjectData? matchingInjectData = _findMatchingInjectData(
        factoryData.targetType,
        factoryData.targetQualifier,
        injectDataList,
      );
      if (matchingInjectData != null) {
        matchedInjectData.add(matchingInjectData);
      }
    }

    // Synthesize abstract factory classes for unmatched @assistedInject
    // constructors. Groups by class to determine isMulti (needed for naming
    // convention). Each unmatched constructor gets its own factory class.
    final factorySpecs = <Class>[];
    final allByClass = <Element, List<AssistedInjectData>>{};
    for (final injectData in injectDataList) {
      (allByClass[injectData.constructor.enclosingElement] ??= []).add(injectData);
    }
    for (final MapEntry(value: entries) in allByClass.entries) {
      final List<AssistedInjectData> unmatched = entries.where((e) => !matchedInjectData.contains(e)).toList();
      if (unmatched.isEmpty) {
        continue;
      }

      // isMulti is based on the total count of @assistedInject constructors on
      // the class, not just unmatched — a class with 2 ctors (one explicitly
      // matched) still applies qualifier suffixes to the remaining unmatched.
      final bool isMulti = entries.length > 1;

      for (final injectData in unmatched) {
        factorySpecs.add(_factoryGen.generateSynthesizedAbstractFactory(
          injectData: injectData,
          isMulti: isMulti,
        ));
      }
    }

    if (factorySpecs.isEmpty) {
      return null;
    }

    // Cross-class collision guard: a synthesized factory class name must not
    // collide with a user-declared @assistedFactory class in the same library,
    // nor with another synthesized factory from a sibling class. Examples:
    //   - class Coffee with @Qualifier(#maker) synthesizes CoffeeMakerFactory,
    //     colliding with single-ctor class CoffeeMaker → CoffeeMakerFactory.
    //   - user-declared @assistedFactory FooFactory collides with a synthesized
    //     FooFactory from an unrelated @Qualifier collision.
    // The case-only collision within a single multi-ctor class is caught earlier
    // in AssistedReader.readAssistedInjects.
    final classNamesInLibrary = <String>{};
    final collidingNames = <String>{};
    for (final factoryData in factoryDataList) {
      if (!classNamesInLibrary.add(factoryData.factoryElement.name!)) {
        collidingNames.add(factoryData.factoryElement.name!);
      }
    }
    for (final spec in factorySpecs) {
      if (!classNamesInLibrary.add(spec.name)) {
        collidingNames.add(spec.name);
      }
    }
    if (collidingNames.isNotEmpty) {
      for (final String name in collidingNames) {
        reader.reporter.errorForElement(
          library,
          message:
              "Synthesized factory class name '$name' collides with another "
              'factory class in the same library.',
          suggestion:
              'Either rename the user-declared @assistedFactory class or pick '
              '@Qualifier symbols that do not capitalize to the same suffix '
              '(e.g. avoid Class=Coffee + @Qualifier(#maker) when sibling class '
              'CoffeeMaker already exists).',
        );
      }
      return null;
    }

    // Sort alphabetically by class name for determinism
    factorySpecs.sort((a, b) => a.name.compareTo(b.name));

    // Build library spec
    final librarySpec = Library((b) => b..body.addAll(factorySpecs));

    // Emit and format
    return emitAndFormat(librarySpec);
  }

  AssistedInjectData? _findMatchingInjectData(
    DartType targetType,
    String? targetQualifier,
    List<AssistedInjectData> injectDataList,
  ) {
    if (targetType case InterfaceType(:final element)) {
      final List<AssistedInjectData> candidates = injectDataList
          .where((data) => data.constructor.enclosingElement == element)
          .toList();

      // Try exact qualifier match first.
      final AssistedInjectData? exactMatch = candidates
          .where((data) => data.key.qualifier == targetQualifier)
          .firstOrNull;
      if (exactMatch != null) {
        return exactMatch;
      }

      // Fallback: unqualified factory with exactly one @assistedInject constructor.
      if (targetQualifier == null && candidates.length == 1) {
        return candidates.first;
      }

      return null;
    }
    return null;
  }
}
