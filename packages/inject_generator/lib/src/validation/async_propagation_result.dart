import 'binding_graph_result.dart';
import 'binding_key.dart';

/// The immutable result of async propagation (Phase 3 of graph validation).
///
/// Produced by `AsyncPropagator` and consumed by `ViewModelFactoryValidator`
/// and `EntryPointValidator`.
class AsyncPropagationResult {
  /// Creates an immutable result, defensively copying the given maps.
  AsyncPropagationResult({
    required Map<BindingKey, bool> asyncBindings,
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingKey>> dependencyEdges,
    Set<BindingKey> shadowedKeys = const {},
  }) : asyncBindings = Map.unmodifiable(asyncBindings),
       _bindingMap = Map.unmodifiable(bindingMap),
       _dependencyEdges = Map.unmodifiable(dependencyEdges),
       _shadowedKeys = Set.unmodifiable(shadowedKeys);

  /// Maps each [BindingKey] to whether the binding requires async
  /// initialization (either directly or transitively).
  ///
  /// In a subcomponent's merged result, a `Foo?` that the child's own `Foo`
  /// shadows holds the status of that `Foo`, because only child code reads it.
  final Map<BindingKey, bool> asyncBindings;

  final Map<BindingKey, BindingSource> _bindingMap;
  final Map<BindingKey, List<BindingKey>> _dependencyEdges;
  final Set<BindingKey> _shadowedKeys;

  /// The key that a read of [key] in this graph really uses.
  ///
  /// `Foo?` reads `Foo` when no exact `Foo?` binding exists, the resolver's
  /// nullable widening. In a subcomponent's merged result it also reads `Foo`
  /// when the child's own `Foo` shadows the parent's exact `Foo?`. The parent's
  /// own readers are not covered by that case.
  BindingKey widenedKey(BindingKey key) =>
      key.isNullable && (_shadowedKeys.contains(key) || !_bindingMap.containsKey(key)) ? key.nonNullable : key;

  /// Whether a dependency reachable from [key] has no binding.
  ///
  /// The async status of such a chain is open: the missing binding could be
  /// async once it exists.
  bool hasUnboundDependency(BindingKey key) {
    final visited = <BindingKey>{key};
    final List<BindingKey> queue = [key];
    for (var i = 0; i < queue.length; i++) {
      final BindingKey current = queue[i];
      if (!_bindingMap.containsKey(current) && !_dependencyEdges.containsKey(current)) return true;
      for (final BindingKey dep in _dependencyEdges[current] ?? const []) {
        if (visited.add(dep)) queue.add(dep);
      }
    }
    return false;
  }

  /// Whether [key] is directly async (i.e. the binding itself is annotated
  /// `@asynchronous` or returns a `Future<T>`), as opposed to being only
  /// transitively async through a dependency.
  bool isDirectlyAsync(BindingKey key) => _bindingMap[key]?.isAsync ?? false;

  /// Finds the origin description of the root async binding for [key].
  ///
  /// If [key] is directly async, returns the origin of [key] itself.
  /// If [key] is only transitively async, returns the origin of the first
  /// directly-async binding reachable from [key].
  /// Returns `null` only when no async root can be found (the binding is
  /// either sync or has no recorded source).
  String? findAsyncRoot(BindingKey key) {
    final BindingSource? source = _bindingMap[key];
    if (source != null && source.isAsync) {
      return source.origin; // Directly async — the binding itself is the root
    }

    // BFS to find the first directly-async binding in the dependency chain.
    // Filter dependencies against [visited] BEFORE enqueueing to keep the
    // queue size O(V) instead of O(E) on diamond-shaped graphs.
    final visited = <BindingKey>{key};
    final List<BindingKey> queue = [];
    for (final BindingKey dep in _dependencyEdges[key] ?? const []) {
      if (visited.add(dep)) queue.add(dep);
    }
    for (var i = 0; i < queue.length; i++) {
      final BindingKey current = queue[i];

      final BindingSource? depSource = _bindingMap[current];
      if (depSource != null && depSource.isAsync) {
        return depSource.origin;
      }

      final List<BindingKey>? deps = _dependencyEdges[current];
      if (deps != null) {
        for (final BindingKey next in deps) {
          if (visited.add(next)) queue.add(next);
        }
      }
    }

    return null;
  }
}
