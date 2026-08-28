import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../extensions/element_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import 'component_reader.dart' show ComponentData;
import 'entry_point_collector.dart';
import 'module_reader.dart' show moduleHasDefaultConstructor;
import 'type_checkers.dart';

/// Result of reading a `@subcomponent`-annotated class.
///
/// An alias of `ComponentData` — the shape is identical (module types +
/// entry points) — kept as a distinct *name* so pipeline code stays
/// explicit about which graph kind it handles, while the record shape
/// itself has a single source of truth.
typedef SubcomponentData = ComponentData;

/// Result of reading an `@subcomponentFactory`-annotated class.
///
/// [moduleParameters] are the factory method's parameters whose type is one
/// of the target subcomponent's own declared modules — they compose exactly
/// like the synthesized factory's module parameters. [valueParameters] are
/// every other parameter — they become instance bindings in the child graph
/// (Dagger's `@BindsInstance` equivalent).
typedef SubcomponentFactoryData = ({
  ClassElement factoryElement,
  MethodElement createMethod,
  ClassElement subcomponentClass,
  List<({ClassElement moduleClass, FormalParameterElement parameter})> moduleParameters,
  List<({FormalParameterElement parameter, DartType type, String? qualifier})> valueParameters,
});

/// Reads `@subcomponent` / `@Subcomponent([...])` annotations and extracts
/// module references and subcomponent entry points.
class SubcomponentReader {
  /// Creates a [SubcomponentReader] reporting through [reporter].
  SubcomponentReader({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  late final _entryPointCollector = EntryPointCollector(reporter: reporter);

  /// Reads the `@subcomponent` annotation from [classElement] and returns
  /// the extracted [SubcomponentData].
  ///
  /// [validate] controls whether module-list problems (unresolved types,
  /// duplicates) are reported — see [readSubcomponentModules] for why a
  /// caller would pass `false`.
  ///
  /// Returns `null` if the annotation could not be read.
  SubcomponentData? readSubcomponent(ClassElement classElement, {bool validate = true}) {
    final List<DartType>? modules = readSubcomponentModules(classElement, validate: validate);
    if (modules == null) {
      return null;
    }

    final List<EntryPoint> entryPoints = _entryPointCollector.collectEntryPoints(classElement);

    return (modules: modules, entryPoints: entryPoints);
  }

  /// Reads only the module list from the `@Subcomponent(...)` annotation.
  ///
  /// Used by the factory builder, which must not touch the subcomponent's
  /// entry points: their return types may reference classes this very build
  /// step is about to generate into the `.factory.dart` part file and would
  /// resolve to `InvalidType` here.
  ///
  /// [validate] defaults to `true`, reporting unresolved-type and duplicate
  /// module errors through [reporter]. The `inject_builder` pipeline reads
  /// the very same annotation a second time (via [readSubcomponent], to
  /// additionally collect entry points) once a module actually installs the
  /// subcomponent — pass `validate: false` there so a malformed module list
  /// is not diagnosed twice: `factory_builder` runs first and is the
  /// authoritative validator, since it is the only pass that ever sees a
  /// `@subcomponent` class that is declared but never installed.
  ///
  /// Returns `null` if the annotation could not be read.
  List<DartType>? readSubcomponentModules(ClassElement classElement, {bool validate = true}) {
    final DartObject? annotation = subcomponentChecker.firstAnnotationOf(classElement);
    if (annotation == null) {
      if (validate) {
        reporter.errorForElement(
          classElement,
          message: "Class '${classElement.name}' is missing @subcomponent annotation metadata.",
          suggestion: 'Ensure the class is annotated with @subcomponent or @Subcomponent([...]).',
        );
      }
      return null;
    }

    final reader = ConstantReader(annotation);

    // Extract module types from Subcomponent.modules field. Duplicates are
    // reported as errors to prevent accidental double-listing that would
    // emit duplicate required parameters in the generated factory.
    final ConstantReader modulesReader = reader.read('modules');
    final modules = <DartType>[];
    final seenModuleElements = <Element>{};
    for (final DartObject obj in modulesReader.listValue) {
      final DartType? dartType = obj.toTypeValue();
      if (dartType == null) {
        if (validate) {
          reporter.errorForElement(
            classElement,
            message:
                "An entry in @Subcomponent([...]) on '${classElement.name}' could not be resolved "
                'to a type.',
            suggestion: 'Fix the unresolved or invalid class reference — check for a typo or a missing import.',
          );
        }
        continue;
      }
      final Element? typeElement = dartType.element;
      if (typeElement != null && !seenModuleElements.add(typeElement)) {
        if (validate) {
          reporter.errorForElement(
            classElement,
            message:
                "Module '${dartType.getDisplayString()}' is listed more than once in @Subcomponent "
                "on '${classElement.name}'.",
            suggestion: 'Remove the duplicate module entry.',
          );
        }
        continue;
      }
      // A `@subcomponent` type listed like a module would silently degrade
      // to an empty module — mirrors the same check in
      // `ComponentReader.readComponent`. Gated by [validate] so the
      // diagnostic is reported once, by the authoritative factory-builder
      // pass (see the doc comment above); the entry is dropped either way.
      if (typeElement != null && subcomponentChecker.hasAnnotationOf(typeElement)) {
        if (validate) {
          reporter.errorForElement(
            classElement,
            message:
                "Type '${dartType.getDisplayString()}' in @Subcomponent([...]) on "
                "'${classElement.name}' is annotated with @subcomponent — a subcomponent cannot "
                'be listed as a module.',
            suggestion: 'Install it via @Module(subcomponents: [${dartType.getDisplayString()}]) instead.',
          );
        }
        continue;
      }
      modules.add(dartType);
    }

    return modules;
  }

  /// Reads the `@subcomponentFactory` annotation from [classElement] and
  /// returns the extracted [SubcomponentFactoryData].
  ///
  /// Mirrors `AssistedReader.readAssistedFactory`'s structural checks
  /// (abstract class, exactly one abstract method) and additionally
  /// classifies each of that method's parameters as either a module
  /// parameter (its type is one of the target subcomponent's own declared
  /// modules) or a value parameter (everything else).
  ///
  /// [validate] controls whether problems are reported — `false` is used by
  /// callers that already know a prior, authoritative pass validated the
  /// same class (see [readSubcomponentModules] for the same pattern).
  ///
  /// Returns `null` if the class is malformed.
  SubcomponentFactoryData? readSubcomponentFactory(ClassElement classElement, {bool validate = true}) {
    if (!classElement.isAbstract) {
      if (validate) {
        reporter.errorForElement(
          classElement,
          message: "Class '${classElement.name}' is annotated with @subcomponentFactory but is not abstract.",
          suggestion: 'Make the class abstract.',
        );
      }
      return null;
    }

    final List<MethodElement> abstractMethods = classElement.methods.where((m) => m.isAbstract).toList();
    if (abstractMethods.isEmpty) {
      if (validate) {
        reporter.errorForElement(
          classElement,
          message: "Factory '${classElement.name}' has no abstract method.",
          suggestion: 'Add exactly one abstract method that returns the installed @subcomponent type.',
        );
      }
      return null;
    }
    if (abstractMethods.length > 1) {
      if (validate) {
        reporter.errorForElement(
          classElement,
          message: "Factory '${classElement.name}' has ${abstractMethods.length} abstract methods.",
          suggestion: 'An @subcomponentFactory class must have exactly one abstract method.',
        );
      }
      return null;
    }

    final MethodElement createMethod = abstractMethods.first;
    final DartType returnType = createMethod.returnType;

    final ClassElement? subcomponentClass = switch (returnType) {
      InterfaceType(element: final ClassElement c) => c,
      _ => null,
    };
    if (subcomponentClass == null) {
      if (validate) {
        reporter.errorForElement(
          createMethod,
          message:
              "Factory method '${createMethod.name}' returns "
              "'${returnType.getDisplayString()}' which is not a class type.",
          suggestion: 'The factory method must return an installed @subcomponent type.',
        );
      }
      return null;
    }
    if (!subcomponentChecker.hasAnnotationOf(subcomponentClass)) {
      if (validate) {
        reporter.errorForElement(
          createMethod,
          message:
              "Factory method '${createMethod.name}' returns '${subcomponentClass.name}' which is not "
              'annotated with @subcomponent.',
          suggestion: 'The factory method must return a class annotated with @subcomponent or @Subcomponent([...]).',
        );
      }
      return null;
    }

    // `validate: false` — module-list problems on the target subcomponent
    // are diagnosed once, where the subcomponent itself is read.
    final List<DartType> subcomponentModuleTypes =
        readSubcomponentModules(subcomponentClass, validate: false) ?? const [];
    final moduleElements = <ClassElement>{
      for (final DartType t in subcomponentModuleTypes)
        if (t case InterfaceType(element: final ClassElement c)) c,
    };

    final moduleParameters = <({ClassElement moduleClass, FormalParameterElement parameter})>[];
    final valueParameters = <({FormalParameterElement parameter, DartType type, String? qualifier})>[];
    final seenModules = <ClassElement>{};
    for (final FormalParameterElement param in createMethod.formalParameters) {
      final ClassElement? paramModuleClass = switch (param.type) {
        InterfaceType(element: final ClassElement c) when moduleElements.contains(c) => c,
        _ => null,
      };
      if (paramModuleClass != null) {
        if (!seenModules.add(paramModuleClass)) {
          if (validate) {
            reporter.errorForElement(
              param,
              message:
                  "Factory method '${createMethod.name}' declares parameter '${param.name}' for module "
                  "'${paramModuleClass.name}' more than once.",
              suggestion: 'Remove the duplicate module parameter.',
            );
          }
          continue;
        }
        moduleParameters.add((moduleClass: paramModuleClass, parameter: param));
      } else {
        valueParameters.add((parameter: param, type: param.type, qualifier: param.readQualifier()));
      }
    }

    if (validate) {
      for (final ClassElement moduleClass in moduleElements) {
        if (seenModules.contains(moduleClass)) {
          continue;
        }
        if (!moduleHasDefaultConstructor(moduleClass)) {
          reporter.errorForElement(
            createMethod,
            message:
                "Subcomponent module '${moduleClass.name}' has no accessible no-argument constructor and "
                "must be declared as a parameter of '${classElement.name}.${createMethod.name}'.",
            suggestion: "Add a '${moduleClass.name}' parameter to the factory method.",
          );
        }
      }
    }

    return (
      factoryElement: classElement,
      createMethod: createMethod,
      subcomponentClass: subcomponentClass,
      moduleParameters: moduleParameters,
      valueParameters: valueParameters,
    );
  }
}
