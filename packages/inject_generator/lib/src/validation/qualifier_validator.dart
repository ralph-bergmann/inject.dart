import '../logging/diagnostic_reporter.dart';
import 'binding_key.dart';
import 'binding_graph_result.dart';

/// Validates that no duplicate bindings exist for the same [BindingKey].
///
/// A conflict occurs when multiple [BindingSource]s register for the same
/// type-plus-qualifier key. This validator reports all such conflicts
/// through the shared [DiagnosticReporter] without throwing exceptions.
class QualifierValidator {
  /// Creates a [QualifierValidator] reporting through [reporter].
  QualifierValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  /// Validates the binding map for duplicate binding conflicts.
  ///
  /// Iterates over [duplicateBindings] (populated by `BindingResolver`)
  /// and emits an error for each key that has more than one source.
  void validate({
    required Map<BindingKey, BindingSource> bindingMap,
    required Map<BindingKey, List<BindingSource>> duplicateBindings,
  }) {
    for (final MapEntry<BindingKey, List<BindingSource>> entry in duplicateBindings.entries) {
      final BindingKey key = entry.key;
      final List<BindingSource> sources = entry.value;

      final String origins = sources.map((s) => s.origin).join(' and ');

      // Use the last source's element for the diagnostic location
      // (the source that introduced the conflict).
      _reporter.errorForElement(
        sources.last.element,
        message: "Duplicate binding for type '${key.debugLabel}': provided by $origins.",
        suggestion: 'Remove duplicate bindings or use different @Qualifier annotations to disambiguate.',
      );
    }
  }
}
