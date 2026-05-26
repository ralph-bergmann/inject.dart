import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../analysis/assisted_reader.dart';
import '../analysis/component_reader.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../builder/inject_builder_options.dart';
import '../logging/diagnostic_reporter.dart';
import 'binding_graph_result.dart';
import 'binding_key.dart';
import 'async_propagation_result.dart';
import 'async_propagator.dart';
import 'binding_resolver.dart';
import 'entry_point_validator.dart';
import 'view_model_factory_validator.dart';
import 'cycle_validator.dart';
import 'qualifier_validator.dart';
import 'reachability_validator.dart';
import 'module_validator.dart';
import 'visibility_validator.dart';

/// The kind of generated output a builder produces.
enum GeneratedOutputKind {
  /// A standalone `.inject.dart` library (from `inject_builder`).
  inject,

  /// A `.factory.dart` part file (from `factory_builder`).
  factory,
}

/// Facade that orchestrates graph validation before code generation.
///
/// Delegates to specialized sub-validators. Each sub-validator reports
/// diagnostics through the shared [DiagnosticReporter] without throwing
/// exceptions for user-facing errors.
class GraphValidator {
  /// Creates a [GraphValidator] reporting through [reporter].
  GraphValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;
  late final _moduleValidator = ModuleValidator(reporter: _reporter);
  late final _visibilityValidator = VisibilityValidator(reporter: _reporter);
  late final _bindingResolver = BindingResolver(reporter: _reporter);
  final _asyncPropagator = AsyncPropagator();
  late final _viewModelFactoryValidator = ViewModelFactoryValidator(reporter: _reporter);
  late final _entryPointValidator = EntryPointValidator(reporter: _reporter);
  late final _cycleValidator = CycleValidator(reporter: _reporter);
  late final _qualifierValidator = QualifierValidator(reporter: _reporter);
  late final _reachabilityValidator = ReachabilityValidator(reporter: _reporter);

  AsyncPropagationResult? _lastAsyncResult;
  BindingGraphResult? _lastGraphResult;
  List<EntryPoint>? _lastValidEntryPoints;

  /// The async binding results from the latest validation run.
  Map<BindingKey, bool> get asyncBindings => _lastAsyncResult?.asyncBindings ?? const {};

  /// The full async propagation result from the latest validation run.
  AsyncPropagationResult? get lastAsyncResult => _lastAsyncResult;

  /// The binding graph from the latest validation run, or `null` if not yet run.
  BindingGraphResult? get lastGraphResult => _lastGraphResult;

  /// The validated entry points from the latest run, or `null` if not yet run.
  List<EntryPoint>? get lastValidEntryPoints => _lastValidEntryPoints;

  /// Validates the full dependency graph for a single component.
  ///
  /// Runs all sub-validators in sequence, collecting all diagnostics
  /// before returning. Does **not** stop after the first error.
  ///
  /// The [sourceLibrary] is the library where the component is declared —
  /// needed for visibility checks against the output type.
  void validate({
    required LibraryElement sourceLibrary,
    required ClassElement componentClass,
    required ComponentData componentData,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
        const [],
    List<TypedefProviderData> typedefProviders = const [],
    GeneratedOutputKind outputKind = GeneratedOutputKind.inject,
    NullableDuplicatePolicy nullableDuplicatePolicy = NullableDuplicatePolicy.error,
  }) {
    _lastAsyncResult = null;
    _lastGraphResult = null;
    _lastValidEntryPoints = null;

    // Sub-validator 0: Module-level constraints (private class, reserved words,
    // qualified/unqualified conflict within a single module).
    _moduleValidator
      ..validateModules(modules)
      ..validateInjectables(injectables);

    // Guard: a @component class without entry points produces an empty shell
    // class. This is almost certainly a user error (missing abstract getters
    // or methods), so we report it as a fatal error.
    if (componentData.entryPoints.isEmpty) {
      _reporter.errorForElement(
        componentClass,
        message:
            "Component '${componentClass.name}' has no entry points. "
            'Declare at least one abstract getter or method that the '
            'component should provide.',
        suggestion:
            'Add an abstract getter, e.g.: '
            '`MyType get myType;`',
      );
      return;
    }

    // Collect all symbols that will appear in the generated .inject.dart output.
    final List<Element> referencedElements = _collectReferencedElements(
      componentClass: componentClass,
      componentData: componentData,
      modules: modules,
      injectables: injectables,
      factories: factories,
    );

    // Sub-validator 1: Visibility checks against the target output type.
    switch (outputKind) {
      case GeneratedOutputKind.inject:
        _visibilityValidator.validateForInjectOutput(sourceLibrary: sourceLibrary, elements: referencedElements);
      case GeneratedOutputKind.factory:
        _visibilityValidator.validateForFactoryOutput(sourceLibrary: sourceLibrary, elements: referencedElements);
    }

    // Sub-validator 1b: Entry-point name conflict detection
    // When multiple interfaces declare an entry point with the same member
    // name, two things can go wrong:
    //  - Different return types: Dart itself will flag a compile error in the
    //    generated class, but we emit an early warning at the component
    //    declaration for a better developer experience.
    //  - Same return type, different qualifiers: Dart sees no conflict
    //    (identical signatures are merged), but the generator cannot decide
    //    which binding to use → error.
    final List<EntryPoint> validEntryPoints = _validateEntryPointNameConflicts(componentData.entryPoints);

    // Sub-validator 2: Binding resolution — Phase 1 (registry) + Phase 2 (dep check)
    final graphResult = _bindingResolver.resolve(
      modules: modules,
      injectables: injectables,
      factories: factories,
      typedefProviders: typedefProviders,
      entryPoints: validEntryPoints,
      allowModuleOverrides: true,
      nullableDuplicatePolicy: nullableDuplicatePolicy,
    );

    // Sub-validator 3: Async propagation — Phase 3
    final asyncResult = _asyncPropagator.propagate(graphResult);
    _lastAsyncResult = asyncResult;
    _lastGraphResult = graphResult;
    _lastValidEntryPoints = validEntryPoints;

    // Sub-validator 4: ViewModel constraints — Phase 4
    _viewModelFactoryValidator.validate(
      graphResult: graphResult,
      asyncResult: asyncResult,
      modules: modules,
      injectables: injectables,
      typedefProviders: typedefProviders,
      factories: factories,
    );

    // Sub-validator 5: Entry-point async signatures — Phase 5
    _entryPointValidator.validate(asyncResult, validEntryPoints);

    // Sub-validator 6: Cycle detection
    _cycleValidator.validate(
      bindingMap: graphResult.bindingMap,
      dependencyEdges: graphResult.dependencyEdges,
    );

    // Sub-validator 7: Qualifier conflicts
    _qualifierValidator.validate(
      bindingMap: graphResult.bindingMap,
      duplicateBindings: graphResult.duplicateBindings,
    );

    // Sub-validator 8: Reachability warnings
    // Collect @provisionListener binding keys — these are implicitly wired
    // and should not trigger "unused binding" warnings.
    // Typed listeners are only exempted when their type argument matches at
    // least one *reachable* provisioned binding; otherwise they are dead code
    // and the reachability warning should fire.

    // First compute which keys are reachable WITHOUT listener exemptions.
    final Set<BindingKey> reachableKeys = ReachabilityValidator.computeReachableKeys(
      bindingMap: graphResult.bindingMap,
      dependencyEdges: graphResult.dependencyEdges,
      entryPoints: validEntryPoints,
    );

    final reachableProvisionedTypes = <DartType>[
      for (final m in modules)
        for (final provider in m.moduleData.providers)
          if (!provider.metadata.isProvisionListener && reachableKeys.contains(provider.key))
            provider.metadata.isAsynchronous ? provider.returnType.unwrapFuture : provider.returnType,
      for (final injectable in injectables)
        if (reachableKeys.contains(injectable.injectable.key)) injectable.classElement.thisType,
    ];

    final listenerExemptKeys = <BindingKey>{
      for (final m in modules)
        for (final provider in m.moduleData.providers)
          if (provider.metadata.isProvisionListener &&
              _listenerMatchesAnyProvisionedType(
                provider.metadata.listenerTypeArgument,
                reachableProvisionedTypes,
              ))
            provider.key,
    };

    _reachabilityValidator.validate(
      bindingMap: graphResult.bindingMap,
      dependencyEdges: graphResult.dependencyEdges,
      entryPoints: validEntryPoints,
      exemptKeys: listenerExemptKeys,
    );
  }

  /// Returns `true` if [listenerTypeArg] is a catch-all (`null`) or matches at
  /// least one of the given [provisionedTypes] via subtype assignment.
  static bool _listenerMatchesAnyProvisionedType(
    DartType? listenerTypeArg,
    List<DartType> provisionedTypes,
  ) {
    if (listenerTypeArg == null) return true;
    if (listenerTypeArg case final InterfaceType listenerInterface) {
      final checker = TypeChecker.fromStatic(listenerInterface);
      return provisionedTypes.any(checker.isAssignableFromType);
    }
    return false;
  }

  /// Collects all elements that will be referenced in generated output.
  List<Element> _collectReferencedElements({
    required ClassElement componentClass,
    required ComponentData componentData,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
    factories,
  }) {
    final elements = <Element>{
      // The component class itself
      componentClass,
    };

    // Module classes
    for (final m in modules) {
      elements.add(m.moduleClass);
    }

    // Injectable classes and their constructors
    for (final injectable in injectables) {
      elements
        ..add(injectable.classElement)
        ..add(injectable.injectable.constructor);
    }

    // Factory classes and their dependency types
    for (final factory in factories) {
      elements.add(factory.factoryElement);
      _addTypeElements(factory.factoryData.targetType, elements);
      for (final ParameterDependency dep in factory.injectData.injectedDependencies) {
        _addTypeElements(dep.type, elements);
      }
    }

    // Entry point return types (the types surfaced in the component interface)
    for (final EntryPoint ep in componentData.entryPoints) {
      final Element element = ep.element;
      DartType? returnType;
      if (element case final PropertyAccessorElement accessor) {
        returnType = accessor.returnType;
      } else if (element case final MethodElement method) {
        returnType = method.returnType;
      }
      if (returnType != null) {
        _addTypeElements(returnType, elements);
      }
    }

    // Provider methods, return types, and parameter types
    for (final m in modules) {
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        elements.add(provider.method);
        _addTypeElements(provider.returnType, elements);

        // Parameter types (dependencies)
        for (final ParameterDependency dep in provider.dependencies) {
          _addTypeElements(dep.type, elements);
        }
      }
    }

    // Injectable dependency types
    for (final injectable in injectables) {
      for (final ParameterDependency dep in injectable.injectable.dependencies) {
        _addTypeElements(dep.type, elements);
      }
    }

    return elements.toList();
  }

  void _addTypeElements(DartType dartType, Set<Element> elements) {
    if (dartType case final InterfaceType interfaceType) {
      elements.add(interfaceType.element);
      for (final DartType typeArgument in interfaceType.typeArguments) {
        _addTypeElements(typeArgument, elements);
      }
    }
  }

  /// Detects entry points that share the same member name across different
  /// interfaces. Returns the list of non-conflicting entry points that
  /// can safely proceed to downstream validation.
  ///
  /// Two cases are distinguished (both are errors):
  /// - **Same return type, different qualifiers**: Dart sees no conflict
  ///   (the signatures are identical), but the generator cannot decide
  ///   which binding to use.
  /// - **Different return types**: The generated class will not compile.
  List<EntryPoint> _validateEntryPointNameConflicts(List<EntryPoint> entryPoints) {
    // Group entry points by member name.
    final byName = <String, List<EntryPoint>>{};
    for (final ep in entryPoints) {
      final String? name = ep.element.name;
      if (name == null) {
        continue;
      }
      byName.putIfAbsent(name, () => []).add(ep);
    }

    final conflictingNames = <String>{};

    for (final MapEntry(key: name, value: eps) in byName.entries) {
      if (eps.length < 2) {
        continue;
      }

      // Check whether all entries share the same BindingKey.
      final Set<BindingKey> distinctKeys = eps.map((ep) => ep.key).toSet();
      if (distinctKeys.length < 2) {
        continue;
      }

      conflictingNames.add(name);

      // Determine whether the return types differ or only the qualifiers.
      final Set<String> distinctTypes = eps.map((ep) => ep.key.typeIdentity).toSet();
      final bool hasTypeMismatch = distinctTypes.length > 1;

      final String details = eps
          .map((ep) {
            final String qualifier = ep.key.qualifier ?? '<unqualified>';
            final String interfaceName = ep.element.enclosingElement?.name ?? '<unknown>';
            return "'#$qualifier' (from '$interfaceName')";
          })
          .join(', ');

      final Element element = eps.first.element;

      if (hasTypeMismatch) {
        // Different return types — the generated class will not compile.
        _reporter.errorForElement(
          element,
          message:
              "Entry point '$name' is declared with incompatible return types "
              'across interfaces: $details. '
              'The generated class will not compile.',
          suggestion:
              'Rename the conflicting members so each has a unique name, '
              'or align the return types.',
        );
      } else {
        // Same return type, different qualifiers — only the generator
        // can detect this because Dart merges the identical signatures.
        _reporter.errorForElement(
          element,
          message:
              "Entry point '$name' is declared with conflicting qualifiers "
              '$details. '
              'The generator cannot determine which binding to use.',
          suggestion:
              'Rename the conflicting members so each has a unique name, '
              'or unify them under a single qualifier.',
        );
      }
    }

    if (conflictingNames.isEmpty) {
      return entryPoints;
    }

    // Filter out all conflicting entry points so downstream validators
    // do not emit misleading secondary errors.
    return entryPoints.where((ep) => !conflictingNames.contains(ep.element.name)).toList();
  }
}
