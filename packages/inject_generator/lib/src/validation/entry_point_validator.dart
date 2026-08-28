import 'package:analyzer/dart/element/element.dart';

import '../analysis/entry_point_collector.dart';
import '../logging/diagnostic_reporter.dart';
import 'async_propagation_result.dart';

/// Validates that component entry-point getters are declared as `Future<T>`
/// (or `Provider<T>`) when their binding chain is async.
///
/// Phase 5 of graph validation. Must be called after `AsyncPropagator` so
/// that [AsyncPropagationResult.asyncBindings] is fully populated.
class EntryPointValidator {
  /// Creates an [EntryPointValidator] reporting through [reporter].
  EntryPointValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  /// Reports each entry point that is async in the binding graph but not
  /// declared as `Future<T>` or `Provider<T>`.
  void validate(AsyncPropagationResult asyncResult, List<EntryPoint> entryPoints) {
    // Group sync-broken entry points by async root to deduplicate diagnostics:
    // N getters depending on the same async root → one aggregated error.
    final Map<String, _AsyncGroup> byRoot = {};
    for (final EntryPoint ep in entryPoints) {
      if (asyncResult.asyncBindings[ep.key] != true) continue;
      if (ep.isFuture || ep.isProvider) continue;

      final String? asyncRoot = asyncResult.findAsyncRoot(ep.key);
      assert(
        asyncRoot != null,
        'asyncBindings[${ep.key}] is true but findAsyncRoot returned null',
      );
      // Namespace the no-root fallback so it cannot collide with a real
      // asyncRoot string that happens to equal another entry's debugLabel.
      final String groupKey = asyncRoot ?? '__noroot__:${ep.key.debugLabel}';
      final _AsyncGroup group = byRoot.putIfAbsent(groupKey, () => _AsyncGroup(asyncRoot: asyncRoot));
      group.add(ep, isDirect: asyncResult.isDirectlyAsync(ep.key));
    }

    for (final _AsyncGroup group in byRoot.values) {
      // Sort entries alphabetically by name so the rendered diagnostic is
      // deterministic across entry-point list orderings.
      group.entries.sort((a, b) => (a.element.name ?? '').compareTo(b.element.name ?? ''));

      final EntryPoint firstEp = group.entries.first;
      final String? asyncRoot = group.asyncRoot;
      // "Direct" wording only applies when every entry in the group is
      // directly async; if any member is transitively async the dependency-
      // chain wording is the accurate description.
      final rootInfo = asyncRoot != null
          ? group.allDirect
                ? " The provider '$asyncRoot' is asynchronous."
                : " The async provider '$asyncRoot' in the dependency chain causes transitive async propagation."
          : '';

      if (group.entries.length == 1) {
        final String getterName = firstEp.element.name ?? '<unknown>';
        final String typeLabel = _typeLabel(firstEp);
        _reporter.errorForElement(
          firstEp.element,
          message:
              "Component getter '$getterName' is declared synchronous but its dependency chain is asynchronous.$rootInfo",
          suggestion: "Change the getter return type from '$typeLabel' to 'Future<$typeLabel>'.",
        );
      } else {
        final List<String> names = _renderNames(group.entries);
        final String namesList = names.join(', ');
        final String typeChanges = group.entries
            .map((ep) {
              final String label = _typeLabel(ep);
              return "'$label' → 'Future<$label>'";
            })
            .join('; ');
        _reporter.errorForElement(
          firstEp.element,
          message:
              'Component entry points [$namesList] are declared synchronous but their dependency chain is asynchronous.$rootInfo',
          suggestion: 'Change return types: $typeChanges.',
        );
      }
    }
  }

  // Render entry-point names for the aggregated message. When more than one
  // entry has a null name (theoretically possible), disambiguate them with an
  // index suffix so the names list does not collapse into duplicate tokens.
  List<String> _renderNames(List<EntryPoint> entries) {
    final int nullCount = entries.where((ep) => ep.element.name == null).length;
    if (nullCount <= 1) {
      return entries.map((ep) => ep.element.name ?? '<unknown>').toList();
    }
    final result = <String>[];
    var unknownIdx = 0;
    for (final EntryPoint ep in entries) {
      final String? name = ep.element.name;
      result.add(name ?? '<unknown#${unknownIdx++}>');
    }
    return result;
  }

  // Use the declared return type's display string so the suggestion remains
  // valid Dart for qualified bindings (debugLabel appends a ' (#qualifier)'
  // suffix that would otherwise leak into the fix-it).
  String _typeLabel(EntryPoint ep) => switch (ep.element) {
    GetterElement(:final returnType) => returnType.getDisplayString(),
    MethodElement(:final returnType) => returnType.getDisplayString(),
    _ => ep.key.debugLabel,
  };
}

class _AsyncGroup {
  _AsyncGroup({required this.asyncRoot});
  final String? asyncRoot;
  var _allDirect = true;
  bool get allDirect => _allDirect;
  final List<EntryPoint> entries = [];
  void add(EntryPoint ep, {required bool isDirect}) {
    entries.add(ep);
    _allDirect = _allDirect && isDirect;
  }
}
