import '../logging/diagnostic_reporter.dart';
import 'binding_key.dart';
import 'binding_graph_result.dart';

/// Validates the dependency graph for cyclic references.
///
/// Uses DFS with visited and in-stack tracking
/// to detect cycles across all connected components. Reports each detected
/// cycle as a fatal error through the shared [DiagnosticReporter].
///
/// **Algorithm note:** Standard DFS detects at least one cycle per strongly
/// connected component, but may not enumerate every simple cycle when
/// multiple cycles share nodes (overlapping SCCs). For example, given
/// A → B → C → A and A → C → A, only one of the two cycles may be
/// reported per run. This is the expected behavior — the user fixes the
/// reported cycle, re-runs, and the next cycle surfaces if one still
/// exists. This matches the approach used by Dagger and other DI
/// frameworks.
class CycleValidator {
  /// Creates a [CycleValidator] reporting through [reporter].
  CycleValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  /// Validates the dependency graph for cycles.
  ///
  /// Traverses all nodes in [dependencyEdges] using DFS. When a back-edge
  /// is detected (a dependency already on the recursion stack), the cycle
  /// is extracted and reported via [DiagnosticReporter.error].
  void validate({
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingKey>> dependencyEdges,
  }) {
    final visited = <BindingKey>{};
    final inStack = <BindingKey>{};
    final path = <BindingKey>[];

    for (final BindingKey node in dependencyEdges.keys) {
      if (!visited.contains(node)) {
        _dfs(node, visited, inStack, path, bindingMap, dependencyEdges);
      }
    }
  }

  void _dfs(
    BindingKey node,
    Set<BindingKey> visited,
    Set<BindingKey> inStack,
    List<BindingKey> path,
    Map<BindingKey, BindingSource> bindingMap,
    Map<BindingKey, List<BindingKey>> dependencyEdges,
  ) {
    visited.add(node);
    inStack.add(node);
    path.add(node);

    final List<BindingKey>? deps = dependencyEdges[node];
    if (deps != null) {
      for (final BindingKey dep in deps) {
        if (inStack.contains(dep)) {
          _reportCycle(dep, path, bindingMap);
        } else if (!visited.contains(dep)) {
          _dfs(dep, visited, inStack, path, bindingMap, dependencyEdges);
        }
      }
    }

    path.removeLast();
    inStack.remove(node);
  }

  void _reportCycle(BindingKey cycleStart, List<BindingKey> path, Map<BindingKey, BindingSource> bindingMap) {
    final int cycleStartIndex = path.indexOf(cycleStart);
    final List<BindingKey> cyclePath = path.sublist(cycleStartIndex);
    final List<String> cycleLabels = [...cyclePath.map((k) => k.debugLabel), cycleStart.debugLabel];
    final String cycleDescription = cycleLabels.join(' → ');

    // Extract source location from the first element in the cycle.
    final BindingSource? source = bindingMap[cycleStart];

    if (source != null) {
      _reporter.errorForElement(
        source.element,
        message: 'Circular dependency detected: $cycleDescription',
        suggestion:
            'Break the cycle by using a Provider<T> for lazy injection, '
            'or refactor the dependency structure to avoid the circular reference.',
      );
    } else {
      _reporter.error(
        filePath: '<dependency-graph>',
        line: 0,
        column: 0,
        message: 'Circular dependency detected: $cycleDescription',
        suggestion:
            'Break the cycle by using a Provider<T> for lazy injection, '
            'or refactor the dependency structure to avoid the circular reference.',
      );
    }
  }
}
