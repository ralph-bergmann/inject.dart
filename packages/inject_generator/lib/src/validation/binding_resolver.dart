import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../analysis/assisted_reader.dart';
import '../analysis/entry_point_collector.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../builder/inject_builder_options.dart';
import '../extensions/dart_type_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import 'binding_graph_result.dart';
import 'binding_key.dart';

/// The context in which a qualifier-mismatch diagnostic is reported.
enum DiagnosticContext {
  /// A dependency required by a provider or constructor.
  dependency,

  /// An entry-point exposed by a component accessor.
  entryPoint,
}

/// Builds the binding registry and validates dependency resolution.
///
/// Phase 1: Registers all bindings (module providers, @inject classes,
///   assisted factories, typedef providers) into the binding map.
/// Phase 2: Verifies that every required dependency and component entry-point
///   has a matching binding.
///
/// Returns a [BindingGraphResult] consumed by `AsyncPropagator` and the
/// downstream validators.
class BindingResolver {
  /// Creates a [BindingResolver] reporting through [reporter].
  BindingResolver({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  var _allowModuleOverrides = false;
  NullableDuplicatePolicy _nullableDuplicatePolicy = NullableDuplicatePolicy.error;

  var _bindingMap = <BindingKey, BindingSource>{};
  var _dependencyEdges = <BindingKey, List<BindingKey>>{};
  var _duplicateBindings = <BindingKey, List<BindingSource>>{};
  var _reportedNullableDuplicates = <({String typeIdentity, String? qualifier})>{};
  ParentBindings? _parentBindings;
  var _parentBindingsUsed = <BindingKey>{};
  var _subcomponentProvidedKeyHints = <BindingKey, String>{};
  String? _subcomponentName;

  /// Child-graph bindings that redeclare a parent-provided key, collected
  /// (not reported immediately) so that two or more child modules rebinding
  /// the same key are reported as a single aggregated diagnostic — see
  /// `_flushParentRebindErrors`, called once at the end of [resolve].
  var _parentRebinds = <BindingKey, List<BindingSource>>{};

  /// Registers all bindings, verifies dependency resolution, and returns
  /// the resulting [BindingGraphResult].
  ///
  /// When [parentBindings] is given, the graph is resolved as a subcomponent
  /// graph: dependency lookups fall back to the parent bindings (child sees
  /// parent), consumed parent keys are recorded in
  /// [BindingGraphResult.parentBindingsUsed], and re-declaring a parent key
  /// inside the child graph is reported as an error.
  ///
  /// [subcomponentFactories] registers the synthesized factory of each
  /// installed subcomponent as a binding of THIS graph (parent side).
  ///
  /// [subcomponentProvidedKeyHints] maps keys that are provided privately
  /// inside an installed subcomponent to that subcomponent's name — used to
  /// enrich missing-binding diagnostics with a "nearby source" note.
  ///
  /// [subcomponentName] names the subcomponent whose child graph is being
  /// resolved (subcomponent mode only) — missing-binding diagnostics mention
  /// it so the reader knows which graph the resolution happened in. Leave it
  /// `null` for component (parent) graphs so their diagnostics are unchanged.
  BindingGraphResult resolve({
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
        const [],
    List<TypedefProviderData> typedefProviders = const [],
    List<EntryPoint> entryPoints = const [],
    bool allowModuleOverrides = false,
    NullableDuplicatePolicy nullableDuplicatePolicy = NullableDuplicatePolicy.error,
    ParentBindings? parentBindings,
    List<({BindingKey key, ClassElement factoryClass})> subcomponentFactories = const [],
    Map<BindingKey, String> subcomponentProvidedKeyHints = const {},
    List<({BindingKey key, FormalParameterElement parameter})> subcomponentFactoryValueParameters = const [],
    String? subcomponentName,
  }) {
    _allowModuleOverrides = allowModuleOverrides;
    _nullableDuplicatePolicy = nullableDuplicatePolicy;
    _bindingMap = {};
    _dependencyEdges = {};
    _duplicateBindings = {};
    _reportedNullableDuplicates = {};
    _parentBindings = parentBindings;
    _parentBindingsUsed = {};
    _subcomponentProvidedKeyHints = Map.of(subcomponentProvidedKeyHints);
    _subcomponentName = subcomponentName;
    _parentRebinds = {};

    // Phase 1: Build the binding map from all known sources.
    _registerModuleProviders(modules);
    _registerInjectables(injectables);
    _registerFactories(factories);
    _registerTypedefProviders(typedefProviders);
    _registerSubcomponentFactories(subcomponentFactories);
    _registerValueParameters(subcomponentFactoryValueParameters);
    _flushParentRebindErrors();

    // Phase 2: Check all dependencies and entry points have matching bindings.
    _validateDependencies(modules, injectables, factories, typedefProviders, entryPoints);

    return BindingGraphResult(
      bindingMap: _bindingMap,
      dependencyEdges: _dependencyEdges,
      duplicateBindings: _duplicateBindings,
      parentBindingsUsed: _parentBindingsUsed,
    );
  }

  /// Registers the synthesized `<Name>Factory` binding of each installed
  /// subcomponent (parent side of the hierarchy).
  ///
  /// The factory has no graph dependencies — the generated implementation is
  /// constructed with the component instance itself.
  void _registerSubcomponentFactories(List<({BindingKey key, ClassElement factoryClass})> subcomponentFactories) {
    for (final factory in subcomponentFactories) {
      final BindingKey key = factory.key;
      final ({ClassElement element, bool isAsync, bool isSingleton, BindingKey key, String origin}) newSource = (
        key: key,
        origin: '${factory.factoryClass.name} (subcomponent factory)',
        isAsync: false,
        isSingleton: false,
        element: factory.factoryClass,
      );

      if (_bindingMap.containsKey(key)) {
        _duplicateBindings.putIfAbsent(key, () => [_bindingMap[key]!]).add(newSource);
      }

      if (_discardIfParentRebind(key, newSource)) continue;
      if (_discardIfNullabilityDuplicate(key, newSource)) continue;

      _bindingMap[key] = newSource;
      _dependencyEdges[key] = const [];
    }
  }

  /// Registers each `@subcomponentFactory` value parameter as an instance
  /// binding of the child graph (Dagger's `@BindsInstance` equivalent).
  ///
  /// A value parameter has no graph dependencies of its own — the value is
  /// already materialized when the factory's `create(...)` method is called.
  void _registerValueParameters(
    List<({BindingKey key, FormalParameterElement parameter})> subcomponentFactoryValueParameters,
  ) {
    for (final valueParameter in subcomponentFactoryValueParameters) {
      final BindingKey key = valueParameter.key;
      final ({FormalParameterElement element, bool isAsync, bool isSingleton, BindingKey key, String origin})
      newSource = (
        key: key,
        origin: '${valueParameter.parameter.name} (subcomponentFactory value parameter)',
        isAsync: false,
        isSingleton: false,
        element: valueParameter.parameter,
      );

      if (_bindingMap.containsKey(key)) {
        _duplicateBindings.putIfAbsent(key, () => [_bindingMap[key]!]).add(newSource);
      }

      if (_discardIfParentRebind(key, newSource)) continue;
      if (_discardIfNullabilityDuplicate(key, newSource)) continue;

      _bindingMap[key] = newSource;
      _dependencyEdges[key] = const [];
    }
  }

  /// Flags a child-graph binding whose key already exists in the parent
  /// graph (re-bind ban: v1 has no child-overrides-parent semantics), for
  /// [_flushParentRebindErrors] to report once resolution finishes.
  ///
  /// Returns `true` when the binding must be discarded.
  bool _discardIfParentRebind(BindingKey key, BindingSource newSource) {
    if (_parentBindings?.lookup(key) == null) {
      return false;
    }
    _parentRebinds.putIfAbsent(key, () => []).add(newSource);
    return true;
  }

  /// Reports one aggregated error per parent-rebound key, collected by
  /// [_discardIfParentRebind] — mirrors `GraphValidator
  /// ._validateDuplicateInstallations`'s aggregation, so a key rebound from
  /// two or more child modules (or an injectable and a module provider, etc.)
  /// is a single diagnostic instead of one per offending declaration.
  void _flushParentRebindErrors() {
    for (final MapEntry<BindingKey, List<BindingSource>> entry in _parentRebinds.entries) {
      final BindingKey key = entry.key;
      final List<BindingSource> rebinds = entry.value;
      final BindingSource parentSource = _parentBindings!.lookup(key)!;
      final String childOrigins = rebinds.map((s) => s.origin).join(', ');
      _reporter.errorForElement(
        rebinds.last.element,
        message:
            "Binding '${key.debugLabel}' ($childOrigins) is already provided by the parent "
            'component (${parentSource.origin}).',
        suggestion:
            'Remove the subcomponent binding(s) and consume the parent binding, or bind a '
            'different type or qualifier — subcomponents cannot override parent bindings.',
      );
    }
  }

  void _registerModuleProviders(List<({ClassElement moduleClass, ModuleData moduleData})> modules) {
    for (final m in modules) {
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        final BindingKey key = provider.key;

        final ({MethodElement element, bool isAsync, bool isSingleton, BindingKey key, String origin}) newSource = (
          key: key,
          origin: '${m.moduleClass.name}.${provider.method.name}',
          isAsync: provider.metadata.isAsynchronous,
          isSingleton: provider.metadata.isSingleton,
          element: provider.method,
        );

        if (_bindingMap.containsKey(key)) {
          final BindingSource existing = _bindingMap[key]!;
          final bool isModuleOverride =
              _allowModuleOverrides &&
              existing.element is MethodElement &&
              existing.element.enclosingElement != provider.method.enclosingElement;
          if (!isModuleOverride) {
            _duplicateBindings.putIfAbsent(key, () => [existing]).add(newSource);
          }
        }

        if (_discardIfParentRebind(key, newSource)) continue;
        if (_discardIfNullabilityDuplicate(key, newSource)) continue;

        _bindingMap[key] = newSource;

        // Track dependency edges for async propagation (Set prevents duplicate edges)
        final deps = <BindingKey>{};
        for (final ParameterDependency dep in provider.dependencies) {
          final BindingKey? depKey = _keyFromType(
            dep.type,
            qualifier: dep.qualifier,
            element: dep.parameter,
            context: 'parameter \'${dep.parameter.name}\' of \'${provider.method.name}\'',
          );
          if (depKey != null) {
            deps.add(depKey);
          }
        }
        _dependencyEdges[key] = deps.toList();
      }
    }
  }

  void _registerInjectables(List<({ClassElement classElement, InjectableData injectable})> injectables) {
    for (final injectable in injectables) {
      final BindingKey key = injectable.injectable.key;

      final ctorSuffix = injectable.injectable.constructorName != null
          ? '.${injectable.injectable.constructorName}'
          : '';
      final ({ClassElement element, bool isAsync, bool isSingleton, BindingKey key, String origin}) newSource = (
        key: key,
        origin: '${injectable.classElement.name}$ctorSuffix (constructor injection)',
        isAsync: false, // Injectables are never directly async
        isSingleton: injectable.injectable.isSingleton,
        element: injectable.classElement,
      );

      if (_bindingMap.containsKey(key)) {
        _duplicateBindings.putIfAbsent(key, () => [_bindingMap[key]!]).add(newSource);
      }

      if (_discardIfParentRebind(key, newSource)) continue;
      if (_discardIfNullabilityDuplicate(key, newSource)) continue;

      _bindingMap[key] = newSource;

      final deps = <BindingKey>{};
      for (final ParameterDependency dep in injectable.injectable.dependencies) {
        final BindingKey? depKey = _keyFromType(
          dep.type,
          qualifier: dep.qualifier,
          element: dep.parameter,
          context: 'parameter \'${dep.parameter.name}\' of \'${injectable.classElement.name}\'',
        );
        if (depKey != null) {
          deps.add(depKey);
        }
      }
      _dependencyEdges[key] = deps.toList();
    }
  }

  void _registerFactories(
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories,
  ) {
    for (final factory in factories) {
      final BindingKey? key = BindingKey.fromDartType(factory.factoryElement.thisType);
      if (key == null) {
        continue;
      }

      final ({ClassElement element, bool isAsync, bool isSingleton, BindingKey key, String origin}) newSource = (
        key: key,
        origin: '${factory.factoryElement.name} (assisted factory)',
        isAsync: false,
        isSingleton: factory.injectData.isSingleton,
        element: factory.factoryElement,
      );

      if (_bindingMap.containsKey(key)) {
        _duplicateBindings.putIfAbsent(key, () => [_bindingMap[key]!]).add(newSource);
      }

      if (_discardIfParentRebind(key, newSource)) continue;
      if (_discardIfNullabilityDuplicate(key, newSource)) continue;

      _bindingMap[key] = newSource;

      final deps = <BindingKey>{};
      for (final ParameterDependency dep in factory.injectData.injectedDependencies) {
        final BindingKey? depKey = _keyFromType(
          dep.type,
          qualifier: dep.qualifier,
          element: dep.parameter,
          context: 'parameter \'${dep.parameter.name}\' of \'${factory.factoryElement.name}\'',
        );
        if (depKey != null) {
          deps.add(depKey);
        }
      }
      _dependencyEdges[key] = deps.toList();
    }
  }

  void _registerTypedefProviders(List<TypedefProviderData> typedefProviders) {
    for (final typedefData in typedefProviders) {
      final BindingKey? key = BindingKey.fromDartType(typedefData.typedefType);
      if (key == null) continue;

      final String typeName = typedefData.typedefType.displayName;
      final ({ConstructorElement element, bool isAsync, bool isSingleton, BindingKey key, String origin}) newSource = (
        key: key,
        origin: '$typeName (typedef provider)',
        isAsync: false,
        isSingleton: false,
        element: typedefData.constructor,
      );

      if (_bindingMap.containsKey(key)) {
        _duplicateBindings.putIfAbsent(key, () => [_bindingMap[key]!]).add(newSource);
      }

      if (_discardIfParentRebind(key, newSource)) continue;
      if (_discardIfNullabilityDuplicate(key, newSource)) continue;

      _bindingMap[key] = newSource;

      final deps = <BindingKey>{};
      for (final ({DartType depType, FormalParameterElement param, String? qualifier, bool passProvider}) injected
          in typedefData.injectedParams) {
        final BindingKey? depKey = BindingKey.fromDartType(injected.depType, qualifier: injected.qualifier);
        if (depKey != null) {
          deps.add(depKey);
        }
      }
      _dependencyEdges[key] = deps.toList();
    }
  }

  /// Checks whether [newSource] has a nullability-counterpart already in the
  /// binding map and, if so, applies [_nullableDuplicatePolicy].
  ///
  /// Returns `true` if [newSource] should be discarded (error policy fired).
  bool _discardIfNullabilityDuplicate(BindingKey key, BindingSource newSource) {
    final BindingSource? variant = _findNullabilityVariant(key);
    if (variant == null) return false;
    return _applyNullableDuplicatePolicy(
      newKey: key,
      newSource: newSource,
      existingSource: variant,
    );
  }

  /// Returns the existing binding for the nullability counterpart of [key].
  BindingSource? _findNullabilityVariant(BindingKey key) {
    return key.isNullable ? _bindingMap[key.nonNullable] : _bindingMap[key.toNullable];
  }

  /// Applies [_nullableDuplicatePolicy] when [newSource] and [existingSource]
  /// differ only in nullability for the same `(typeIdentity, qualifier)` pair.
  ///
  /// Returns `true` if the new binding should be discarded (error policy).
  bool _applyNullableDuplicatePolicy({
    required BindingKey newKey,
    required BindingSource newSource,
    required BindingSource existingSource,
  }) {
    if (_nullableDuplicatePolicy == NullableDuplicatePolicy.allow) {
      return false;
    }

    final identityKey = (typeIdentity: newKey.typeIdentity, qualifier: newKey.qualifier);
    final bool firstReport = _reportedNullableDuplicates.add(identityKey);
    if (!firstReport) {
      return _nullableDuplicatePolicy == NullableDuplicatePolicy.error;
    }

    final BindingSource nullableSource = newKey.isNullable ? newSource : existingSource;
    final BindingSource nonNullableSource = newKey.isNullable ? existingSource : newSource;

    final String nullableOrigin = _formatOriginWithExtras(nullableSource);
    final String nonNullableOrigin = _formatOriginWithExtras(nonNullableSource);

    final String message =
        "Duplicate binding for type '${nonNullableSource.key.debugLabel}': "
        "both nullable ('${nullableSource.key.debugLabel}' from $nullableOrigin) "
        "and non-nullable ('${nonNullableSource.key.debugLabel}' from $nonNullableOrigin) "
        'variants are bound for the same key.';
    final String suggestion = _nullableDuplicatePolicy == NullableDuplicatePolicy.error
        ? "Remove one of the bindings, or set "
              "'nullable_duplicate_binding_policy: allow' in build.yaml to permit both."
        : 'Remove one of the bindings to silence this warning.';

    if (_nullableDuplicatePolicy == NullableDuplicatePolicy.error) {
      _reporter.errorForElement(newSource.element, message: message, suggestion: suggestion);
      _reporter.errorForElement(existingSource.element, message: message, suggestion: suggestion);
      return true;
    } else {
      _reporter.warningForElement(newSource.element, message: message, suggestion: suggestion);
      _reporter.warningForElement(existingSource.element, message: message, suggestion: suggestion);
      return false;
    }
  }

  /// Builds the nullable-duplicate-diagnostic origin string, appending the
  /// library URI and any additional intra-key duplicates.
  String _formatOriginWithExtras(BindingSource source) {
    final String withUri = '${source.origin} [${source.element.library?.uri}]';
    final List<BindingSource>? duplicates = _duplicateBindings[source.key];
    if (duplicates == null) return withUri;
    final List<String> extras = duplicates
        .where((s) => s.origin != source.origin)
        .map((s) => '${s.origin} [${s.element.library?.uri}]')
        .toList(growable: false);
    if (extras.isEmpty) return withUri;
    return '$withUri (also: ${extras.join(', ')})';
  }

  void _validateDependencies(
    List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories,
    List<TypedefProviderData> typedefProviders,
    List<EntryPoint> entryPoints,
  ) {
    // Collect all required dependencies
    final requiredDeps = <({BindingKey key, DartType dartType, Element source, String context})>[];

    for (final m in modules) {
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        for (final ParameterDependency dep in provider.dependencies) {
          final BindingKey? depKey = _keyFromType(
            dep.type,
            qualifier: dep.qualifier,
            element: dep.parameter,
            context: 'parameter \'${dep.parameter.name}\' of \'${provider.method.name}\'',
          );
          if (depKey != null) {
            requiredDeps.add((
              key: depKey,
              dartType: dep.type,
              source: dep.parameter,
              context: '${m.moduleClass.name}.${provider.method.name}',
            ));
          }
        }
      }
    }

    for (final injectable in injectables) {
      for (final ParameterDependency dep in injectable.injectable.dependencies) {
        final BindingKey? depKey = _keyFromType(
          dep.type,
          qualifier: dep.qualifier,
          element: dep.parameter,
          context: 'parameter \'${dep.parameter.name}\' of \'${injectable.classElement.name}\'',
        );
        if (depKey != null) {
          requiredDeps.add((
            key: depKey,
            dartType: dep.type,
            source: dep.parameter,
            context: injectable.classElement.name!,
          ));
        }
      }
    }

    for (final factory in factories) {
      for (final ParameterDependency dep in factory.injectData.injectedDependencies) {
        final BindingKey? depKey = _keyFromType(
          dep.type,
          qualifier: dep.qualifier,
          element: dep.parameter,
          context: 'parameter \'${dep.parameter.name}\' of \'${factory.factoryElement.name}\'',
        );
        if (depKey != null) {
          requiredDeps.add((
            key: depKey,
            dartType: dep.type,
            source: dep.parameter,
            context: '${factory.factoryElement.name!} (assisted factory)',
          ));
        }
      }
    }

    for (final typedefData in typedefProviders) {
      for (final (
            :DartType depType,
            :FormalParameterElement param,
            :String? qualifier,
            passProvider: _,
          )
          in typedefData.injectedParams) {
        final BindingKey? depKey = _keyFromType(
          depType,
          qualifier: qualifier,
          element: param,
          context: 'parameter \'${param.name}\' of \'${typedefData.typedefType.displayName}\'',
        );
        if (depKey != null) {
          requiredDeps.add((
            key: depKey,
            dartType: depType,
            source: param,
            context: typedefData.typedefType.displayName,
          ));
        }
      }
    }

    // Check each dependency against the binding map
    for (final dep in requiredDeps) {
      if (_bindingMap.containsKey(dep.key)) {
        continue;
      }

      // Nullable-widening fallback: Foo? → Foo.
      // Dart allows implicit widening (Foo? x = nonNullableFoo), so a non-nullable
      // binding satisfies a nullable dep without any adapter code.
      // Skip Future<T>?/Provider<T>? — async/provider propagation is the
      // intended resolution path; widening here would yield a misleading
      // "(also tried 'Future<T>')" diagnostic for that case.
      final unwrap = dep.dartType.unwrapProviderAndFuture();
      final bool eligibleForWidening = !unwrap.isFuture && !unwrap.isProvider;

      if (eligibleForWidening && dep.key.isNullable && _bindingMap.containsKey(dep.key.nonNullable)) {
        continue;
      }

      // Hierarchical fallback: subcomponent dependencies resolve against the
      // parent graph (child sees parent, never the other way around).
      if (_resolveThroughParent(dep.key, eligibleForWidening: eligibleForWidening)) {
        continue;
      }

      List<BindingSource>? related = _findRelatedBindings(dep.key);
      if (related == null && eligibleForWidening && dep.key.isNullable) {
        // Second pass: a qualified non-nullable binding (`@Q Foo`) is also a
        // qualifier-mismatch hint for a `Foo?` request.
        related = _findRelatedBindings(dep.key.nonNullable);
      }
      if (related != null) {
        _reportQualifierMismatch(
          element: dep.source,
          missingKey: dep.key,
          related: related,
          contextSuffix: 'required by ${dep.context}',
          diagnosticContext: DiagnosticContext.dependency,
        );
      } else {
        final String alsoTried = (dep.key.isNullable && eligibleForWidening)
            ? " (also tried '${dep.key.nonNullable.debugLabel}')"
            : '';
        final String? subcomponentName = _subcomponentHintFor(dep.key);
        final String subcomponentNote = subcomponentName != null
            ? " Note: '${dep.key.debugLabel}' is provided inside subcomponent "
                  "'$subcomponentName' and is not visible to the parent."
            : '';
        final String suggestion = subcomponentName != null
            ? "Expose the binding as an entry point on '$subcomponentName' and re-export it "
                  "through a module provider that consumes the subcomponent's factory."
            : 'Add a @provides method in a module that returns this type, '
                  'or annotate the class with @inject for constructor injection.';
        _reporter.errorForElement(
          dep.source,
          message:
              'No binding found for type \'${dep.key.debugLabel}\' '
              'required by ${dep.context}$_inSubcomponentSuffix$alsoTried.$subcomponentNote',
          suggestion: suggestion,
        );
      }
    }

    // Check entry-point return types have bindings
    for (final ep in entryPoints) {
      final BindingKey epKey = ep.key;
      if (_bindingMap.containsKey(epKey)) {
        continue;
      }

      // Nullable-widening fallback for entry points.
      if (epKey.isNullable && _bindingMap.containsKey(epKey.nonNullable)) {
        continue;
      }

      // Hierarchical fallback: subcomponent entry points may expose parent
      // bindings, read through the parent reference.
      if (_resolveThroughParent(epKey, eligibleForWidening: true)) {
        continue;
      }

      final Element element = ep.element;

      List<BindingSource>? related = _findRelatedBindings(epKey);
      if (related == null && epKey.isNullable) {
        related = _findRelatedBindings(epKey.nonNullable);
      }
      if (related != null) {
        _reportQualifierMismatch(
          element: element,
          missingKey: epKey,
          related: related,
          contextSuffix: 'exposed by \'${element.name ?? '<unknown>'}\'',
          diagnosticContext: DiagnosticContext.entryPoint,
        );
      } else {
        final String alsoTried = epKey.isNullable ? " (also tried '${epKey.nonNullable.debugLabel}')" : '';
        _reporter.errorForElement(
          element,
          message:
              'No binding found for entry-point type \'${epKey.debugLabel}\' '
              'exposed by \'${element.name ?? '<unknown>'}\'$_inSubcomponentSuffix$alsoTried.',
          suggestion:
              'Add a @provides method in a module that returns this type, '
              'or annotate the class with @inject for constructor injection.',
        );
      }
    }
  }

  /// Resolves [key] against the parent bindings (subcomponent mode).
  ///
  /// Records the effective parent key in `parentBindingsUsed` so the codegen
  /// knows which parent providers must be promoted to fields. Returns `true`
  /// when the parent satisfies the key (exact or via nullable widening).
  bool _resolveThroughParent(BindingKey key, {required bool eligibleForWidening}) {
    final ParentBindings? parent = _parentBindings;
    if (parent == null) {
      return false;
    }
    if (parent.lookup(key) != null) {
      _parentBindingsUsed.add(key);
      return true;
    }
    if (eligibleForWidening && key.isNullable && parent.lookup(key.nonNullable) != null) {
      _parentBindingsUsed.add(key.nonNullable);
      return true;
    }
    return false;
  }

  /// Message suffix naming the subcomponent graph being resolved, e.g.
  /// `" in subcomponent 'HttpSubcomponent'"` — empty for component (parent)
  /// graphs so their diagnostics stay byte-identical.
  String get _inSubcomponentSuffix => _subcomponentName != null ? " in subcomponent '$_subcomponentName'" : '';

  /// Returns the name of the subcomponent that privately provides [key],
  /// or `null` when no installed subcomponent provides it.
  String? _subcomponentHintFor(BindingKey key) =>
      _subcomponentProvidedKeyHints[key] ?? (key.isNullable ? _subcomponentProvidedKeyHints[key.nonNullable] : null);

  /// Searches the binding map for entries whose [BindingKey.typeIdentity]
  /// matches [missingKey], but whose qualifier differs.
  List<BindingSource>? _findRelatedBindings(BindingKey missingKey) {
    final related = <BindingSource>[];
    for (final MapEntry<BindingKey, BindingSource> entry in _bindingMap.entries) {
      if (entry.key.typeIdentity == missingKey.typeIdentity && entry.key != missingKey) {
        related.add(entry.value);
      }
    }
    return related.isEmpty ? null : related;
  }

  /// Reports a qualifier-mismatch error with context about available bindings.
  void _reportQualifierMismatch({
    required Element element,
    required BindingKey missingKey,
    required List<BindingSource> related,
    required String contextSuffix,
    required DiagnosticContext diagnosticContext,
  }) {
    final String available = related
        .map(
          (b) => b.key.qualifier != null ? '#${b.key.qualifier} (from ${b.origin})' : 'unqualified (from ${b.origin})',
        )
        .join(', ');

    final String typeLabel = missingKey.typeIdentity.replaceAll(RegExp(r'[^<>,?]+#'), '');

    if (missingKey.qualifier == null) {
      // Scenario 1: Unqualified requested, only qualified exist
      final String action = switch (diagnosticContext) {
        DiagnosticContext.entryPoint => 'Add a @Qualifier annotation to the component accessor.',
        DiagnosticContext.dependency => 'Add a @Qualifier annotation to the injection site.',
      };
      _reporter.errorForElement(
        element,
        message: 'No unqualified binding for \'$typeLabel\' $contextSuffix.',
        suggestion: 'Available qualified bindings: $available. $action',
      );
    } else {
      // Scenario 2: Qualifier requested, different qualifiers exist
      _reporter.errorForElement(
        element,
        message: 'No binding for \'${missingKey.debugLabel}\' $contextSuffix.',
        suggestion: 'Available bindings for $typeLabel: $available.',
      );
    }
  }

  /// Creates a [BindingKey] from a [DartType], reporting unsupported types.
  BindingKey? _keyFromType(DartType dartType, {required Element element, required String context, String? qualifier}) {
    final BindingKey? key = BindingKey.fromDartType(dartType, qualifier: qualifier);
    if (key != null) {
      return key;
    }

    // Unsupported type shape — outside the type-system coverage boundary.
    final String typeDescription = switch (dartType) {
      RecordType() => 'Record type',
      FunctionType() => 'Function type',
      _ => 'Unsupported type \'${dartType.getDisplayString()}\'',
    };

    _reporter.errorForElement(
      element,
      message: '$typeDescription is not supported as a dependency in $context.',
      suggestion: 'Use an interface type or wrap the dependency in a typedef or class.',
    );

    return null;
  }
}
