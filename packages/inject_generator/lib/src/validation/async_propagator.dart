import 'async_propagation_result.dart';
import 'binding_graph_result.dart';
import 'binding_key.dart';

/// Propagates async status transitively through the dependency graph.
///
/// Phase 3 of graph validation: reads [BindingGraphResult] and produces an
/// [AsyncPropagationResult] where every binding that depends (directly or
/// transitively) on an async provider is marked async.
///
/// Does not emit any diagnostics.
class AsyncPropagator {
  /// Returns an [AsyncPropagationResult] marking every binding that is async
  /// directly or transitively.
  ///
  /// When [graphResult] merges a subcomponent with its parent, [ownKeys] holds
  /// the subcomponent's own bindings.
  AsyncPropagationResult propagate(BindingGraphResult graphResult, {Set<BindingKey> ownKeys = const {}}) {
    final Map<BindingKey, bool> asyncBindings = {};

    // Initialize async status from direct annotations
    for (final MapEntry<BindingKey, BindingSource> entry in graphResult.bindingMap.entries) {
      asyncBindings[entry.key] = entry.value.isAsync;
    }

    // The resolver satisfies a child's `Foo?` with the child's own `Foo` before
    // the parent's exact `Foo?`. Only the child's reads move to `Foo`, so the
    // parent's readers keep the status of the parent's exact binding.
    // shortcut: a raw `Future<Foo>?` dependency also counts as shadowed although
    // the resolver does not widen it; add per-edge eligibility if a child ever
    // binds `Future<Foo>` beside a parent's exact `Future<Foo>?`.
    final Set<BindingKey> shadowedKeys = {
      for (final BindingKey key in ownKeys)
        if (!key.isNullable && !ownKeys.contains(key.toNullable) && graphResult.bindingMap.containsKey(key.toNullable))
          key.toNullable,
    };

    // A `Foo?` dependency that only `Foo` satisfies has no binding of its own,
    // so async status and the async root must reach `Foo` through an extra edge.
    // A child's exact `Foo?` means the parent has none, so a parent's reader of
    // `Foo?` resolved to the parent's `Foo` and must not see the child's status.
    final Map<BindingKey, List<BindingKey>> dependencyEdges = {
      for (final MapEntry(:key, value: deps) in graphResult.dependencyEdges.entries)
        key: [
          for (final BindingKey dep in deps)
            (ownKeys.contains(key) ? shadowedKeys.contains(dep) : dep.isNullable && ownKeys.contains(dep))
                ? dep.nonNullable
                : dep,
        ],
      for (final List<BindingKey> deps in graphResult.dependencyEdges.values)
        for (final BindingKey dep in deps)
          if (dep.isNullable && !graphResult.bindingMap.containsKey(dep)) dep: [dep.nonNullable],
    };

    // Propagate until stable: if any dependency is async, the dependent
    // binding becomes async too.
    var changed = true;
    while (changed) {
      changed = false;
      for (final MapEntry<BindingKey, List<BindingKey>> entry in dependencyEdges.entries) {
        final BindingKey bindingKey = entry.key;
        if (asyncBindings[bindingKey] == true) {
          continue; // Already async, no change possible
        }

        for (final BindingKey depKey in entry.value) {
          if (asyncBindings[depKey] == true) {
            asyncBindings[bindingKey] = true;
            changed = true;
            break;
          }
        }
      }
    }

    // Generated child code looks the status up under its declared `Foo?` key.
    for (final BindingKey shadowed in shadowedKeys) {
      asyncBindings[shadowed] = asyncBindings[shadowed.nonNullable]!;
    }

    return AsyncPropagationResult(
      asyncBindings: asyncBindings,
      bindingMap: graphResult.bindingMap,
      dependencyEdges: dependencyEdges,
      shadowedKeys: shadowedKeys,
    );
  }
}
