import '../analysis/entry_point_collector.dart';
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

  /// Computes the set of [BindingKey]s reachable from [entryPoints] and
  /// [extraRoots] by walking [dependencyEdges].
  ///
  /// [extraRoots] holds keys consumed from outside this graph, such as parent
  /// bindings a subcomponent reads. Their own dependencies count as reachable.
  static Set<BindingKey> computeReachableKeys({
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingKey>> dependencyEdges,
    required List<EntryPoint> entryPoints,
    Set<BindingKey> extraRoots = const {},
  }) {
    final reachable = <BindingKey>{};
    final queue = <BindingKey>[];

    void visit(BindingKey key) {
      // `Foo?` is satisfied by a `Foo` binding, the resolver's nullable widening.
      final BindingKey bound = key.isNullable && !bindingMap.containsKey(key) ? key.nonNullable : key;
      if (bindingMap.containsKey(bound) && reachable.add(bound)) {
        queue.add(bound);
      }
    }

    for (final ep in entryPoints) {
      visit(ep.key);
    }
    extraRoots.forEach(visit);

    while (queue.isNotEmpty) {
      dependencyEdges[queue.removeLast()]?.forEach(visit);
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
  ///
  /// [extraRoots] is forwarded to [computeReachableKeys].
  void validate({
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingKey>> dependencyEdges,
    required List<EntryPoint> entryPoints,
    Set<BindingKey> exemptKeys = const {},
    Set<BindingKey> extraRoots = const {},
  }) {
    if (bindingMap.isEmpty) {
      return;
    }

    final Set<BindingKey> reachable = computeReachableKeys(
      bindingMap: bindingMap,
      dependencyEdges: dependencyEdges,
      entryPoints: entryPoints,
      extraRoots: extraRoots,
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
