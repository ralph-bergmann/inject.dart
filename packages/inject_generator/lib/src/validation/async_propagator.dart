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
  AsyncPropagationResult propagate(BindingGraphResult graphResult) {
    final Map<BindingKey, bool> asyncBindings = {};

    // Initialize async status from direct annotations
    for (final MapEntry<BindingKey, BindingSource> entry in graphResult.bindingMap.entries) {
      asyncBindings[entry.key] = entry.value.isAsync;
    }

    // Propagate until stable: if any dependency is async, the dependent
    // binding becomes async too.
    var changed = true;
    while (changed) {
      changed = false;
      for (final MapEntry<BindingKey, List<BindingKey>> entry in graphResult.dependencyEdges.entries) {
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

    return AsyncPropagationResult(
      asyncBindings: asyncBindings,
      bindingMap: graphResult.bindingMap,
      dependencyEdges: graphResult.dependencyEdges,
    );
  }
}
