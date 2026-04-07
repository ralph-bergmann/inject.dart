import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../analysis/assisted_reader.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import 'async_propagation_result.dart';
import 'binding_graph_result.dart';
import 'binding_key.dart';

/// Validates ViewModelFactory typedef providers for ownership and sync-only
/// constraints.
///
/// Phase 4 of graph validation. Must be called after `AsyncPropagator` so
/// that transitive async status is available.
class ViewModelFactoryValidator {
  /// Creates a [ViewModelFactoryValidator] reporting through [reporter].
  ViewModelFactoryValidator({required DiagnosticReporter reporter}) : _reporter = reporter;
  final DiagnosticReporter _reporter;

  /// Reports ViewModelFactory typedef providers that violate ownership or the
  /// sync-only constraint.
  void validate({
    required BindingGraphResult graphResult,
    required AsyncPropagationResult asyncResult,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    required List<TypedefProviderData> typedefProviders,
    required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
    factories,
    bool Function(DartType)? isViewModelFactory,
  }) {
    final predicate = isViewModelFactory ?? (t) => t.isViewModelFactory;
    for (final typedefData in typedefProviders) {
      if (!predicate(typedefData.typedefType)) {
        continue;
      }

      // Extract the ViewModel type from the typedef's type arguments.
      // ViewModelFactory<T> has exactly one type argument: the ViewModel type.
      final InstantiatedTypeAliasElement? alias = typedefData.typedefType.alias;
      if (alias == null || alias.typeArguments.isEmpty) {
        continue;
      }

      final DartType viewModelType = alias.typeArguments.first;
      final BindingKey? viewModelKey = BindingKey.fromDartType(viewModelType);
      if (viewModelKey == null) {
        continue;
      }

      final String typeName = viewModelType.displayName;

      // Compute violations once — they depend on the ViewModel type, not on
      // individual factories.
      final bool singletonViolation = _isSingletonBinding(viewModelKey, modules, injectables);
      final bool asyncViolation = asyncResult.asyncBindings[viewModelKey] == true;
      String rootInfo = '';
      if (asyncViolation) {
        final String? asyncRoot = asyncResult.findAsyncRoot(viewModelKey);
        rootInfo = asyncRoot != null
            ? asyncResult.isDirectlyAsync(viewModelKey)
                  ? ' The provider \'$asyncRoot\' is asynchronous.'
                  : ' The async provider \'$asyncRoot\' in the dependency chain '
                        'causes transitive async propagation.'
            : '';
      }

      // Report errors on every factory that uses this typedef so each gets its
      // own diagnostic anchor instead of falling back to the internal constructor.
      for (final errorElement in _findFactoriesForTypedef(typedefData, factories)) {
        if (singletonViolation) {
          _reporter.errorForElement(
            errorElement,
            message:
                'ViewModelFactory<$typeName> cannot use a @singleton ViewModel. '
                'Widget-owned view models must be created per widget instance.',
            suggestion:
                'Remove @singleton from the ViewModel binding, or inject the '
                'ViewModel as a regular dependency instead of using ViewModelFactory.',
          );
        }

        if (asyncViolation) {
          _reporter.errorForElement(
            errorElement,
            message:
                'ViewModelFactory<$typeName> cannot use an asynchronous ViewModel. '
                'ViewModelBuilder requires synchronous provider resolution.$rootInfo',
            suggestion: 'Move async state into injected services instead of the ViewModel itself.',
          );
        }
      }
    }
  }

  /// Returns whether the binding for [key] is marked as `@singleton`.
  ///
  /// Uses last-match-wins semantics to respect module override order.
  bool _isSingletonBinding(
    BindingKey key,
    List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    List<({ClassElement classElement, InjectableData injectable})> injectables,
  ) {
    bool? result;
    for (final m in modules) {
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        if (provider.key == key) {
          result = provider.metadata.isSingleton;
        }
      }
    }
    for (final injectable in injectables) {
      if (injectable.injectable.key == key) {
        result = injectable.injectable.isSingleton;
      }
    }
    return result ?? false;
  }

  /// Finds the factory elements that use the given typedef provider.
  ///
  /// Equality is keyed on [BindingKey] derived from the type, not raw
  /// `DartType ==`, so the match survives cross-build analyzer Element
  /// identity differences.
  ///
  /// If no factory matches, the discovery invariant ("every
  /// [TypedefProviderData] has a consuming factory") is violated — that is a
  /// generator bug. We surface an internal-error diagnostic AND fall back to
  /// the typedef constructor so user-visible violations still emit somewhere.
  List<Element> _findFactoriesForTypedef(
    TypedefProviderData typedefData,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories,
  ) {
    final BindingKey? typedefKey = BindingKey.fromDartType(typedefData.typedefType);
    final result = <Element>[];
    for (final factory in factories) {
      final bool hasTypedef = factory.injectData.injectedDependencies.any((dep) {
        if (typedefKey == null) return dep.type == typedefData.typedefType;
        return BindingKey.fromDartType(dep.type) == typedefKey;
      });
      if (hasTypedef) {
        result.add(factory.factoryElement);
      }
    }

    if (result.isEmpty) {
      _reporter.errorForElement(
        typedefData.constructor,
        message:
            "Internal generator inconsistency: typedef provider '${typedefData.typedefType.displayName}' "
            'has no consuming factory.',
        suggestion: 'This is a generator bug — please file an issue with the affected source file.',
      );
      return [typedefData.constructor];
    }
    return result;
  }
}
