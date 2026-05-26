import 'package:analyzer/dart/element/element.dart';

import '../analysis/component_reader.dart';
import 'async_propagation_result.dart';
import 'binding_graph_result.dart';
import 'binding_key.dart';

/// Renders a formatted dependency-graph tree for a single `@component`.
///
/// Call [render] to produce the tree string. Off by default — only
/// instantiated when `debug_graph: true` is set on the builder options.
class GraphPrinter {
  /// Creates a [GraphPrinter] for one component's resolved graph.
  GraphPrinter({
    required ClassElement componentClass,
    required List<EntryPoint> entryPoints,
    required BindingGraphResult graphResult,
    required AsyncPropagationResult asyncResult,
  })  : _componentClass = componentClass,
        _entryPoints = entryPoints,
        _graphResult = graphResult,
        _asyncResult = asyncResult {
    // Invert dependencyEdges once: dependency → set of dependents (receivers).
    // Set semantics so a class that requests the same dep type twice in one
    // constructor doesn't double-count its single parent as two receivers.
    final receiverSets = <BindingKey, Set<BindingKey>>{};
    for (final MapEntry(key: parent, value: deps) in graphResult.dependencyEdges.entries) {
      for (final dep in deps) {
        receiverSets.putIfAbsent(dep, () => <BindingKey>{}).add(parent);
      }
    }
    // Materialize into sorted lists for determinism; capture shared keys.
    for (final entry in receiverSets.entries) {
      final sorted = entry.value.toList()..sort((a, b) => a.debugLabel.compareTo(b.debugLabel));
      _reverseMap[entry.key] = sorted;
      if (sorted.length >= 2) {
        _sharedKeys.add(entry.key);
      }
    }
  }

  static const int _maxDepth = 20;

  static const _tee = '├── ';
  static const _ell = '└── ';
  static const _pipe = '│   ';
  static const _blank = '    ';

  final ClassElement _componentClass;
  final List<EntryPoint> _entryPoints;
  final BindingGraphResult _graphResult;
  final AsyncPropagationResult _asyncResult;

  final Map<BindingKey, List<BindingKey>> _reverseMap = {};
  final Set<BindingKey> _sharedKeys = {};

  /// Renders the complete tree string for this component.
  String render() {
    if (_entryPoints.isEmpty) return '';

    final out = StringBuffer();
    _renderMainTree(out);
    if (_sharedKeys.isNotEmpty) {
      _renderSharedBlock(out);
    }
    return out.toString();
  }

  void _renderMainTree(StringBuffer out) {
    out.writeln('[inject_generator] Dependency graph for ${_componentClass.name}:');
    out.writeln('  ${_componentClass.name}');

    final sortedEntryPoints = _entryPoints.toList()
      ..sort((a, b) => a.key.debugLabel.compareTo(b.key.debugLabel));

    for (var i = 0; i < sortedEntryPoints.length; i++) {
      final ep = sortedEntryPoints[i];
      final isLast = i == sortedEntryPoints.length - 1;
      final connector = isLast ? _ell : _tee;
      final childPrefix = isLast ? '  $_blank' : '  $_pipe';
      _renderNode(ep.key, '  $connector', childPrefix, {}, 0, out);
    }
  }

  void _renderSharedBlock(StringBuffer out) {
    out.writeln();
    out.writeln('  (shared bindings — each appears in the tree above as <name>...)');

    final sortedShared = _sharedKeys.toList()
      ..sort((a, b) => a.debugLabel.compareTo(b.debugLabel));

    for (final sharedKey in sortedShared) {
      final isSingleton = _graphResult.bindingMap[sharedKey]?.isSingleton ?? false;
      final isAsync = _asyncResult.asyncBindings[sharedKey] ?? false;
      final receivers = (_reverseMap[sharedKey] ?? []).map((k) => k.debugLabel).toList();
      final label = sharedKey.formattedLabel(
        isSingleton: isSingleton,
        isAsync: isAsync,
        receivers: receivers,
      );
      out.writeln('  $label');

      final deps = _graphResult.dependencyEdges[sharedKey] ?? [];
      if (deps.isNotEmpty) {
        // Seed `seen` with the block root so a non-shared cycle hidden under
        // a shared root (validator-missed cycle) can't recurse to depth limit.
        final blockSeen = {sharedKey};
        final sortedDeps = deps.toList()..sort((a, b) => a.debugLabel.compareTo(b.debugLabel));
        for (var i = 0; i < sortedDeps.length; i++) {
          final dep = sortedDeps[i];
          final isLast = i == sortedDeps.length - 1;
          final connector = isLast ? _ell : _tee;
          final childPrefix = isLast ? _blank : _pipe;
          _renderNode(dep, '  $connector', '  $childPrefix', blockSeen, 0, out);
        }
      }
    }
  }

  void _renderNode(
    BindingKey key,
    String connector,
    String childPrefix,
    Set<BindingKey> seen,
    int depth,
    StringBuffer out,
  ) {
    if (depth > _maxDepth) {
      out.writeln('$connector… (depth limit reached)');
      return;
    }

    if (_sharedKeys.contains(key) || seen.contains(key)) {
      out.writeln('$connector${key.typeNameOnly}...');
      return;
    }

    final isSingleton = _graphResult.bindingMap[key]?.isSingleton ?? false;
    final isAsync = _asyncResult.asyncBindings[key] ?? false;
    out.writeln('$connector${key.formattedLabel(isSingleton: isSingleton, isAsync: isAsync)}');

    final deps = _graphResult.dependencyEdges[key] ?? [];
    if (deps.isEmpty) return;

    final nextSeen = {...seen, key};
    final sortedDeps = deps.toList()..sort((a, b) => a.debugLabel.compareTo(b.debugLabel));
    for (var i = 0; i < sortedDeps.length; i++) {
      final dep = sortedDeps[i];
      final isLast = i == sortedDeps.length - 1;
      final connector2 = '$childPrefix${isLast ? _ell : _tee}';
      final childPrefix2 = '$childPrefix${isLast ? _blank : _pipe}';
      _renderNode(dep, connector2, childPrefix2, nextSeen, depth + 1, out);
    }
  }
}
