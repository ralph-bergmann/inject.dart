import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/annotation_reader.dart';
import '../analysis/assisted_reader.dart';
import '../analysis/module_reader.dart';
import '../analysis/subcomponent_reader.dart' show SubcomponentFactoryData;
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
    // Collect @assistedInject data. Component classes are excluded here too —
    // this scan is independent of FactoryBuilder's (re-derived from
    // library.classes), so the exclusion is load-bearing in the mixed-file
    // case where a malformed component coexists with a valid non-component
    // @assistedInject class in the same library.
    final List<ClassElement> assistedInjectClasses = library.classes
        .where((c) => reader.isAssistedInject(c) && !reader.isComponent(c))
        .toList();

    final injectDataList = <AssistedInjectData>[];
    for (final classElement in assistedInjectClasses) {
      injectDataList.addAll(reader.readAssistedInjects(classElement));
    }

    // Collect @subcomponent classes — each gets a public abstract factory
    // class in this part file so user code can reference it on clean builds.
    final List<ClassElement> subcomponentClasses = library.classes.where(reader.isSubcomponent).toList();

    if (injectDataList.isEmpty && subcomponentClasses.isEmpty) {
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

    // Collect @subcomponentFactory data — an explicit factory replaces the
    // synthesized `<Name>Factory` for its target subcomponent (mirrors
    // @assistedFactory's precedence over a synthesized factory).
    final List<ClassElement> subcomponentFactoryClasses = library.classes.where(reader.isSubcomponentFactory).toList();
    final subcomponentFactoryDataList = <SubcomponentFactoryData>[];
    for (final factoryClass in subcomponentFactoryClasses) {
      final SubcomponentFactoryData? data = reader.readSubcomponentFactory(factoryClass);
      if (data != null) {
        subcomponentFactoryDataList.add(data);
      }
    }

    // A subcomponent may have at most one explicit factory — this is the
    // single, authoritative pass over the library's @subcomponentFactory
    // classes, so it is also the only place this is checked.
    final subcomponentFactoriesByTarget = <ClassElement, List<SubcomponentFactoryData>>{};
    for (final data in subcomponentFactoryDataList) {
      (subcomponentFactoriesByTarget[data.subcomponentClass] ??= []).add(data);
    }
    for (final MapEntry(key: subcomponentClass, value: dataForTarget) in subcomponentFactoriesByTarget.entries) {
      if (dataForTarget.length > 1) {
        for (final data in dataForTarget.skip(1)) {
          reader.reporter.errorForElement(
            data.factoryElement,
            message:
                "Subcomponent '${subcomponentClass.name}' already has an explicit @subcomponentFactory "
                "('${dataForTarget.first.factoryElement.name}').",
            suggestion: 'A subcomponent may have at most one explicit @subcomponentFactory class.',
          );
        }
      }
    }
    final Set<ClassElement> matchedSubcomponentClasses = subcomponentFactoriesByTarget.keys.toSet();

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
    for (final data in subcomponentFactoryDataList) {
      referencedElements.add(data.factoryElement);
    }

    // Subcomponent factories reference the subcomponent type and its modules.
    final subcomponentModulesByClass = <ClassElement, List<({ClassElement moduleClass, ModuleData moduleData})>>{};
    for (final subcomponentClass in subcomponentClasses) {
      referencedElements.add(subcomponentClass);
      // An explicit factory replaces the synthesized one — nothing to
      // synthesize for this subcomponent.
      if (matchedSubcomponentClasses.contains(subcomponentClass)) {
        continue;
      }
      // Only the module list is read here — entry points may reference types
      // that this very build step is about to generate into the part file.
      final List<DartType>? moduleTypes = reader.readSubcomponentModules(subcomponentClass);
      if (moduleTypes == null) {
        continue;
      }
      final modules = <({ClassElement moduleClass, ModuleData moduleData})>[];
      for (final DartType moduleType in moduleTypes) {
        if (moduleType case InterfaceType(element: final ClassElement moduleClass)) {
          modules.add((moduleClass: moduleClass, moduleData: reader.readModule(moduleClass)));
          referencedElements.add(moduleClass);
        }
      }
      subcomponentModulesByClass[subcomponentClass] = modules;
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
        factorySpecs.add(
          _factoryGen.generateSynthesizedAbstractFactory(
            injectData: injectData,
            isMulti: isMulti,
          ),
        );
      }
    }

    for (final MapEntry<ClassElement, List<({ClassElement moduleClass, ModuleData moduleData})>> entry
        in subcomponentModulesByClass.entries) {
      factorySpecs.add(
        _factoryGen.generateSubcomponentAbstractFactory(
          subcomponentClass: entry.key,
          modules: entry.value,
        ),
      );
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
