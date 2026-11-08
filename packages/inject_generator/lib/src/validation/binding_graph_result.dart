import 'package:analyzer/dart/element/element.dart';

import 'binding_key.dart';

/// Describes the origin of a binding in the dependency graph.
typedef BindingSource = ({BindingKey key, String origin, bool isAsync, bool isSingleton, Element element});

/// A parameter declared `Provider<T>`, recorded for the check that runs after
/// async propagation.
///
/// [heldBackError] is the missing-binding error of a parameter whose reader
/// kept the `Provider` wrapper in the binding key. The resolver cannot report
/// it yet: when `T` is async, the async error replaces it.
typedef ProviderParameter = ({
  FormalParameterElement parameter,
  String requiredBy,
  BindingKey valueKey,
  ({String message, String suggestion})? heldBackError,
});

/// The immutable result of binding resolution (Phase 1 + 2 of graph validation).
///
/// Produced by `BindingResolver` and consumed by `AsyncPropagator`,
/// `ViewModelFactoryValidator`, `EntryPointValidator`,
/// `ProviderParameterValidator`, `CycleValidator`, `QualifierValidator`, and
/// `ReachabilityValidator`.
class BindingGraphResult {
  /// Creates an immutable result, defensively copying the given maps.
  BindingGraphResult({
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingKey>> dependencyEdges,
    required Map<BindingKey, List<BindingSource>> duplicateBindings,
    Set<BindingKey> parentBindingsUsed = const {},
    List<ProviderParameter> providerParameters = const [],
  }) : bindingMap = Map.unmodifiable(bindingMap),
       dependencyEdges = Map.unmodifiable(
         dependencyEdges.map((k, v) => MapEntry(k, List<BindingKey>.unmodifiable(v))),
       ),
       duplicateBindings = Map.unmodifiable(
         duplicateBindings.map((k, v) => MapEntry(k, List<BindingSource>.unmodifiable(v))),
       ),
       parentBindingsUsed = Set.unmodifiable(parentBindingsUsed),
       providerParameters = List.unmodifiable(providerParameters);

  /// Maps each [BindingKey] to its [BindingSource] origin information.
  final Map<BindingKey, BindingSource> bindingMap;

  /// Maps each [BindingKey] to the list of [BindingKey]s it depends on.
  final Map<BindingKey, List<BindingKey>> dependencyEdges;

  /// Bindings that were registered more than once for the same [BindingKey].
  ///
  /// Maps each duplicate key to all sources that attempted to register it
  /// (including the first one).
  final Map<BindingKey, List<BindingSource>> duplicateBindings;

  /// Parent-graph keys that this (subcomponent) graph consumes.
  ///
  /// Empty for component graphs. For subcomponent graphs, contains exactly
  /// the keys resolved through the parent reference — the codegen promotes
  /// these parent providers to fields so the generated subcomponent can
  /// address them as `_parent._<provider>`.
  final Set<BindingKey> parentBindingsUsed;

  /// The parameters declared `Provider<T>` in this graph, checked once async
  /// status is known.
  final List<ProviderParameter> providerParameters;
}

/// A read-only view of a parent component's resolved bindings, used to
/// resolve subcomponent dependencies hierarchically (child sees parent).
class ParentBindings {
  /// Creates a view over the parent's binding map.
  ParentBindings(Map<BindingKey, BindingSource> bindings) : bindings = Map.unmodifiable(bindings);

  /// The parent graph's bindings by key.
  final Map<BindingKey, BindingSource> bindings;

  /// Returns the parent binding for [key], or `null` if the parent does not
  /// provide it.
  BindingSource? lookup(BindingKey key) => bindings[key];
}
