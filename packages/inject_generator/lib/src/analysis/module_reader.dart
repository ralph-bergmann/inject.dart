import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/binding_key.dart';
import 'type_checkers.dart';

/// Binding metadata extracted from method-level annotations.
typedef BindingMetadata = ({
  bool isSingleton,
  bool isAsynchronous,
  bool isProvisionListener,
  DartType? listenerTypeArgument,
  String? qualifier,
});

/// A single provider method descriptor from a `@module` class.
typedef ProviderDescriptor = ({
  BindingKey key,
  MethodElement method,
  DartType returnType,
  List<ParameterDependency> dependencies,
  BindingMetadata metadata,
});

/// A parameter dependency with optional qualifier.
typedef ParameterDependency = ({FormalParameterElement parameter, DartType type, String? qualifier, bool isProvider});

/// Result of reading a `@module`-annotated class.
///
/// `installedSubcomponents` contains the `@subcomponent` types listed in the
/// module's `@Module(subcomponents: [...])` parameter, in declaration order.
///
/// `includes` contains the other `@module` types listed in this module's
/// `@Module(includes: [...])` parameter, in declaration order — the raw,
/// single-level list as read off this class's own annotation. Transitive
/// expansion (following each included module's own `includes`, with cycle
/// detection and dedup) happens separately, in [ModuleReader.expandModules].
typedef ModuleData = ({
  List<ProviderDescriptor> providers,
  bool hasDefaultConstructor,
  List<DartType> installedSubcomponents,
  List<DartType> includes,
});

/// Returns `true` when [cls] has a public unnamed constructor that can be
/// called with no arguments (i.e. `Module()` is valid Dart).
///
/// Returns `false` for abstract classes, generic classes, classes with no
/// unnamed constructor, private constructors, and constructors with required
/// parameters.
///
/// A top-level function (rather than a private `ModuleReader` method) so
/// [SubcomponentReader] can reuse the exact same rule when validating an
/// explicit `@subcomponentFactory`'s module parameters without depending on
/// a full `ModuleReader` instance (which would re-run `@provides` validation
/// and risk double-diagnosing the same module).
bool moduleHasDefaultConstructor(ClassElement cls) {
  if (cls.isAbstract) {
    return false;
  }
  // Generic classes need type arguments at the call site; the generated
  // `Module()` fallback would lack them and infer `dynamic`.
  if (cls.typeParameters.isNotEmpty) {
    return false;
  }
  final ConstructorElement? ctor = cls.unnamedConstructor;
  if (ctor == null) {
    return false;
  }
  if (!ctor.isPublic) {
    return false;
  }
  return ctor.formalParameters.every(
    (p) => !p.isRequiredPositional && !p.isRequiredNamed,
  );
}

/// Reads `@module`-annotated classes and extracts `@provides` method
/// descriptors with their return types, dependencies, and binding metadata.
class ModuleReader {
  /// Creates a [ModuleReader] reporting through [reporter].
  ModuleReader({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  /// Extracts the type argument `T` from `ProvisionListener<T>`.
  ///
  /// Returns `null` for catch-all listeners (`ProvisionListener<Object>` or
  /// raw `ProvisionListener`), meaning the listener fires for all provisions.
  /// Returns the concrete [DartType] for type-scoped listeners.
  static DartType? _extractListenerTypeArgument(DartType returnType) {
    if (returnType case final InterfaceType interfaceType) {
      for (final InterfaceType type in [interfaceType, ...interfaceType.allSupertypes]) {
        if (provisionListenerInterfaceChecker.isExactlyType(type)) {
          final List<DartType> typeArgs = type.typeArguments;
          if (typeArgs.isNotEmpty && !typeArgs.first.isDartCoreObject && typeArgs.first is! DynamicType) {
            return typeArgs.first;
          }
          return null;
        }
      }
    }
    return null;
  }

  /// Reads the `@module` class and returns extracted [ModuleData].
  ModuleData readModule(ClassElement classElement) {
    final providers = <ProviderDescriptor>[];

    for (final MethodElement method in classElement.methods) {
      if (!providesChecker.hasAnnotationOf(method)) {
        continue;
      }

      final bool isSingleton = singletonChecker.hasAnnotationOf(method);
      final bool isAsynchronous = asynchronousChecker.hasAnnotationOf(method);
      bool isProvisionListener = provisionListenerChecker.hasAnnotationOf(method);
      final String? qualifier = method.readQualifier();

      // Validate @provisionListener usage
      if (isProvisionListener) {
        final DartType returnType = method.returnType;
        if (!provisionListenerInterfaceChecker.isAssignableFromType(returnType)) {
          reporter.errorForElement(
            method,
            message:
                "Method '${classElement.name}.${method.name}' is annotated with "
                "@provisionListener but returns '${returnType.getDisplayString()}' "
                'which does not implement ProvisionListener.',
            suggestion:
                'Change the return type to a class that implements ProvisionListener, '
                'or remove the @provisionListener annotation.',
          );
          isProvisionListener = false;
        }
        if (!isSingleton) {
          reporter.infoForElement(
            method,
            message:
                "Provider '${classElement.name}.${method.name}' is annotated with "
                '@provisionListener without @singleton — it will be treated as '
                'a singleton automatically.',
            suggestion:
                'You can add @singleton explicitly to silence this notice, '
                'but it is not required.',
          );
        }
      }

      final dependencies = <ParameterDependency>[];
      for (final FormalParameterElement param in method.formalParameters) {
        dependencies.add((parameter: param, type: param.type, qualifier: param.readQualifier(), isProvider: false));
      }

      // When @asynchronous, unwrap Future<T> to use T for the binding key.
      // The original Future<T> return type is preserved in ProviderDescriptor
      // for code generation.
      final DartType keyType = isAsynchronous ? method.returnType.unwrapFuture : method.returnType;

      final BindingKey? key = BindingKey.fromDartType(keyType, qualifier: qualifier);
      if (key == null) {
        final String typeDescription = switch (keyType) {
          RecordType() => 'Record type',
          FunctionType() => 'Function type',
          _ => "Unsupported type '${keyType.getDisplayString()}'",
        };

        reporter.errorForElement(
          method,
          message:
              '$typeDescription is not supported as a provider return type '
              "in '${classElement.name}.${method.name}'.",
          suggestion: 'Use an interface type or wrap the dependency in a typedef or class.',
        );
        continue;
      }

      providers.add((
        key: key,
        method: method,
        returnType: method.returnType,
        dependencies: dependencies,
        metadata: (
          isSingleton: isSingleton,
          isAsynchronous: isAsynchronous,
          isProvisionListener: isProvisionListener,
          listenerTypeArgument: isProvisionListener ? _extractListenerTypeArgument(method.returnType) : null,
          qualifier: qualifier,
        ),
      ));
    }

    final bool hasDefaultConstructor = moduleHasDefaultConstructor(classElement);
    final List<DartType> installedSubcomponents = _readInstalledSubcomponents(classElement);
    final List<DartType> includes = _readIncludes(classElement);
    return (
      providers: providers,
      hasDefaultConstructor: hasDefaultConstructor,
      installedSubcomponents: installedSubcomponents,
      includes: includes,
    );
  }

  /// Reads the `includes` list from the `@Module(...)` annotation.
  ///
  /// Duplicates and types without a `@module` annotation are reported as
  /// errors and dropped from the result — mirrors [_readInstalledSubcomponents]
  /// exactly, but checks [moduleChecker] instead of [subcomponentChecker].
  /// Cross-module cycle detection happens later, in [expandModules] — the
  /// reader only sees one class at a time.
  List<DartType> _readIncludes(ClassElement classElement) {
    final DartObject? annotation = moduleChecker.firstAnnotationOf(classElement);
    if (annotation == null) {
      return const [];
    }

    final reader = ConstantReader(annotation);
    final ConstantReader includesReader = reader.read('includes');
    final includes = <DartType>[];
    final seenElements = <Element>{};
    for (final DartObject obj in includesReader.listValue) {
      final DartType? dartType = obj.toTypeValue();
      if (dartType == null) {
        reporter.errorForElement(
          classElement,
          message:
              "An entry in @Module(includes: ...) on '${classElement.name}' could not be "
              'resolved to a type.',
          suggestion: 'Fix the unresolved or invalid class reference — check for a typo or a missing import.',
        );
        continue;
      }
      final Element? typeElement = dartType.element;
      if (typeElement == null) {
        reporter.errorForElement(
          classElement,
          message:
              "Type '${dartType.getDisplayString()}' in @Module(includes: ...) on "
              "'${classElement.name}' has no associated class and cannot be used as an included module.",
          suggestion: 'Use a concrete class annotated with @module.',
        );
        continue;
      }
      if (!seenElements.add(typeElement)) {
        reporter.errorForElement(
          classElement,
          message:
              "Module '${dartType.getDisplayString()}' is listed more than once in "
              "@Module(includes: ...) on '${classElement.name}'.",
          suggestion: 'Remove the duplicate includes entry.',
        );
        continue;
      }
      if (!moduleChecker.hasAnnotationOf(typeElement)) {
        reporter.errorForElement(
          classElement,
          message:
              "Type '${dartType.getDisplayString()}' in @Module(includes: ...) on "
              "'${classElement.name}' is not annotated with @module.",
          suggestion:
              "Add @module to '${dartType.getDisplayString()}', or remove it from "
              'the includes list.',
        );
        continue;
      }
      includes.add(dartType);
    }
    return includes;
  }

  /// Expands [directModules] by transitively following each module's
  /// `@Module(includes: [...])` list, producing a flattened list suitable
  /// for feeding straight into discovery and binding resolution exactly as
  /// if every included module had been listed directly.
  ///
  /// The result places every transitively-included-only module first
  /// (dependency-first / sibling-declaration order preserved from the
  /// include-graph traversal), followed by every directly-listed module in
  /// its original `directModules` order. Binding resolution treats a later
  /// entry as overriding an earlier one for the same key (see
  /// `BindingResolver`), so this ordering guarantees directly-listed modules
  /// always take precedence over anything pulled in transitively — even a
  /// module reached only through a different, later-listed umbrella module —
  /// while declaration order among direct modules, and among sibling
  /// included modules, is unchanged.
  ///
  /// A module reachable through more than one include path is included
  /// exactly once (first-reached position wins — Dagger-style diamond
  /// dedup). A cycle (a module that transitively includes itself) is
  /// reported as an element-located diagnostic naming the cycle; the cyclic
  /// edge is not expanded further, so this always terminates.
  List<({ClassElement moduleClass, ModuleData moduleData})> expandModules(List<ClassElement> directModules) {
    final resultModules = <({ClassElement moduleClass, ModuleData moduleData})>[];
    final visited = <ClassElement>{};
    final visiting = <ClassElement>{};

    void visit(ClassElement module, List<ClassElement> path) {
      if (visited.contains(module)) {
        return;
      }
      if (visiting.contains(module)) {
        final int cycleStart = path.indexOf(module);
        final List<ClassElement> loop = cycleStart >= 0 ? path.sublist(cycleStart) : path;
        final String cycleDescription = [...loop, module].map((m) => m.name).join(' -> ');
        reporter.errorForElement(
          path.isNotEmpty ? path.last : module,
          message: 'Module include cycle detected: $cycleDescription.',
          suggestion:
              'Remove one of the @Module(includes: ...) entries in this cycle so the include graph '
              'has no cycle.',
        );
        return;
      }

      visiting.add(module);
      final ModuleData data = readModule(module);
      for (final DartType includedType in data.includes) {
        final Element? element = includedType.element;
        if (element is ClassElement) {
          visit(element, [...path, module]);
        } else {
          reporter.errorForElement(
            module,
            message:
                "Module '${includedType.getDisplayString()}' included by '${module.name}' does not "
                'resolve to a class and cannot be used as an included module.',
            suggestion: 'Reference a concrete class annotated with @module directly, not a typedef or type alias.',
          );
        }
      }
      visiting.remove(module);
      visited.add(module);
      resultModules.add((moduleClass: module, moduleData: data));
    }

    for (final ClassElement module in directModules) {
      visit(module, const []);
    }

    // `resultModules` is dependency-first (a module always appears after
    // everything it includes), which only guarantees that a directly-listed
    // module outranks *its own* includes — not that every directly-listed
    // module outranks every transitively-included module. For example, with
    // directModules = [A, B] where only B declares includes: [C], the DFS
    // above yields [A, C, B]: C (transitively included via B) lands after A,
    // an unrelated, earlier direct module, even though direct modules must
    // always take precedence over anything pulled in transitively.
    //
    // Fix that up with a stable partition: every included-only module first
    // (preserving the dependency-first / sibling-declaration-order relative
    // order the DFS already computed), then every directly-listed module,
    // in its original `directModules` order. This keeps both required
    // guarantees: direct-over-included is now absolute regardless of where
    // an umbrella pulling in the conflicting module sits in the list, and
    // among direct modules (and among included-only siblings) declaration
    // order is unchanged.
    final directSet = directModules.toSet();
    final includedOnly = resultModules.where((m) => !directSet.contains(m.moduleClass));
    final directOnly = resultModules.where((m) => directSet.contains(m.moduleClass));
    return [...includedOnly, ...directOnly];
  }

  /// Reads the `subcomponents` list from the `@Module(...)` annotation.
  ///
  /// Duplicates and types without a `@subcomponent` annotation are reported
  /// as errors and dropped from the result. Cross-module duplicate detection
  /// (the same subcomponent installed by two different modules of one
  /// component) happens later in the validation phase — the reader only
  /// sees one library at a time.
  List<DartType> _readInstalledSubcomponents(ClassElement classElement) {
    final DartObject? annotation = moduleChecker.firstAnnotationOf(classElement);
    if (annotation == null) {
      return const [];
    }

    final reader = ConstantReader(annotation);
    final ConstantReader subcomponentsReader = reader.read('subcomponents');
    final installedSubcomponents = <DartType>[];
    final seenElements = <Element>{};
    for (final DartObject obj in subcomponentsReader.listValue) {
      final DartType? dartType = obj.toTypeValue();
      if (dartType == null) {
        reporter.errorForElement(
          classElement,
          message:
              "An entry in @Module(subcomponents: ...) on '${classElement.name}' could not be "
              'resolved to a type.',
          suggestion: 'Fix the unresolved or invalid class reference — check for a typo or a missing import.',
        );
        continue;
      }
      final Element? typeElement = dartType.element;
      if (typeElement == null) {
        reporter.errorForElement(
          classElement,
          message:
              "Type '${dartType.getDisplayString()}' in @Module(subcomponents: ...) on "
              "'${classElement.name}' has no associated class and cannot be used as a subcomponent.",
          suggestion: 'Use a concrete class annotated with @subcomponent.',
        );
        continue;
      }
      if (!seenElements.add(typeElement)) {
        reporter.errorForElement(
          classElement,
          message:
              "Subcomponent '${dartType.getDisplayString()}' is listed more than once in "
              "@Module(subcomponents: ...) on '${classElement.name}'.",
          suggestion: 'Remove the duplicate subcomponent entry.',
        );
        continue;
      }
      if (!subcomponentChecker.hasAnnotationOf(typeElement)) {
        reporter.errorForElement(
          classElement,
          message:
              "Type '${dartType.getDisplayString()}' in @Module(subcomponents: ...) on "
              "'${classElement.name}' is not annotated with @subcomponent.",
          suggestion:
              "Add @subcomponent to '${dartType.getDisplayString()}', or remove it from "
              'the subcomponents list.',
        );
        continue;
      }
      installedSubcomponents.add(dartType);
    }
    return installedSubcomponents;
  }
}
