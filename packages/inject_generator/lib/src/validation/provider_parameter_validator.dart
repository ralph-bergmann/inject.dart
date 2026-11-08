import '../extensions/dart_type_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import 'async_propagation_result.dart';
import 'binding_graph_result.dart';
import 'binding_key.dart';

/// Reports each parameter declared `Provider<T>` whose value type has an async
/// dependency chain: `Provider<T>.get()` returns `T` synchronously, so no
/// provider exists to pass there.
///
/// Must be called after `AsyncPropagator`, because async status does not exist
/// during binding resolution.
class ProviderParameterValidator {
  /// Creates a [ProviderParameterValidator] reporting through [reporter].
  ProviderParameterValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  /// Reports the async [parameters], and the held-back missing-binding error
  /// of every other parameter that has one.
  void validate(AsyncPropagationResult asyncResult, List<ProviderParameter> parameters) {
    for (final ProviderParameter p in parameters) {
      final BindingKey key = asyncResult.widenedKey(p.valueKey);
      if (asyncResult.asyncBindings[key] != true) {
        if (p.heldBackError case (:final message, :final suggestion)) {
          _reporter.errorForElement(p.parameter, message: message, suggestion: suggestion);
        }
        continue;
      }

      final String? asyncRoot = asyncResult.findAsyncRoot(key);
      final rootInfo = asyncRoot == null
          ? ''
          : asyncResult.isDirectlyAsync(key)
          ? " The provider '$asyncRoot' is asynchronous."
          : " The async provider '$asyncRoot' in the dependency chain causes transitive async propagation.";
      final String declared = p.parameter.type.getDisplayString();
      final String value = p.parameter.type.unwrapProviderParam().type.getDisplayString();

      _reporter.errorForElement(
        p.parameter,
        message:
            "Parameter '${p.parameter.name}' required by ${p.requiredBy} is declared '$declared' "
            'but its dependency chain is asynchronous.$rootInfo',
        suggestion: "Change the parameter type from '$declared' to '$value'.",
      );
    }
  }
}
