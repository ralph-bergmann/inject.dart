import '../analysis/component_reader.dart';
import '../logging/diagnostic_reporter.dart';
import 'binding_key.dart';
import 'binding_graph_result.dart';

/// Warns about bindings that are never reached from any component entry point.
///
/// Unreachable bindings are a code smell (unused module providers or
/// injectables) but not a fatal error — the build continues. Diagnostics
/// are emitted as warnings through [DiagnosticReporter].
class ReachabilityValidator {
  /// Creates a [ReachabilityValidator] reporting through [reporter].
  ReachabilityValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  /// Computes the set of [BindingKey]s reachable from [entryPoints] via BFS
  /// through [dependencyEdges].
  static Set<BindingKey> computeReachableKeys({
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingKey>> dependencyEdges,
    required List<EntryPoint> entryPoints,
  }) {
    final reachable = <BindingKey>{};
    final queue = <BindingKey>[];

    for (final ep in entryPoints) {
      if (bindingMap.containsKey(ep.key) && reachable.add(ep.key)) {
        queue.add(ep.key);
      }
    }

    while (queue.isNotEmpty) {
      final BindingKey current = queue.removeLast();
      final List<BindingKey>? deps = dependencyEdges[current];
      if (deps == null) {
        continue;
      }
      for (final BindingKey dep in deps) {
        if (bindingMap.containsKey(dep) && reachable.add(dep)) {
          queue.add(dep);
        }
      }
    }

    return reachable;
  }

  /// Validates that all bindings are reachable from at least one entry point.
  ///
  /// Traverses the dependency graph starting from all [entryPoints] keys
  /// through [dependencyEdges], then reports any binding in [bindingMap]
  /// that was never visited.
  ///
  /// Bindings whose keys appear in [exemptKeys] are excluded from the
  /// unreachable check. This is used for infrastructure bindings such as
  /// `@provisionListener` providers that are wired implicitly and do not
  /// need a component entry point to be considered "used".
  void validate({
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingKey>> dependencyEdges,
    required List<EntryPoint> entryPoints,
    Set<BindingKey> exemptKeys = const {},
  }) {
    if (bindingMap.isEmpty) {
      return;
    }

    final Set<BindingKey> reachable = computeReachableKeys(
      bindingMap: bindingMap,
      dependencyEdges: dependencyEdges,
      entryPoints: entryPoints,
    );

    // Report unreachable bindings as warnings (sorted for deterministic output).
    // Exempt keys (e.g. @provisionListener bindings) are excluded — they are
    // implicitly wired and do not require a component entry point.
    final List<BindingKey> unreachable =
        bindingMap.keys.where((key) => !reachable.contains(key) && !exemptKeys.contains(key)).toList()
          ..sort((a, b) => a.debugLabel.compareTo(b.debugLabel));

    for (final key in unreachable) {
      final BindingSource source = bindingMap[key]!;

      _reporter.warningForElement(
        source.element,
        message:
            "Binding '${key.debugLabel}' is registered but never used "
            'by any component entry point.',
        suggestion: 'Remove the binding from the module, or add a component getter that exposes this type.',
      );
    }
  }
}
