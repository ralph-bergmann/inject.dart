import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../analysis/module_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../validation/binding_key.dart';
import 'provider_generator.dart';

/// Info about a matching listener provider to be called after provision.
typedef ListenerCallInfo = ({String providerClassName, String fieldName});

/// Determines which provision listeners match a given provisioned type
/// and generates the corresponding call info for code generation.
class ListenerGenerator {
  /// Returns [ListenerCallInfo] for each listener that matches
  /// [provisionedType].
  ///
  /// Listeners are matched using `isAssignableFrom` semantics:
  /// - `ProvisionListener<Object>` (catch-all) matches all types.
  /// - `ProvisionListener<Heater>` matches `Heater` and subtypes.
  ///
  /// [selfKey] prevents a listener from firing for its own provision
  /// (infinite recursion prevention).
  ///
  /// For `@asynchronous` providers, pass the unwrapped type (`T`, not
  /// `Future<T>`) as [provisionedType].
  static List<ListenerCallInfo> matchingListeners({
    required DartType provisionedType,
    required List<({ClassElement moduleClass, ProviderDescriptor descriptor})> listenerProviders,
    BindingKey? selfKey,
    String? componentPrefix,
  }) {
    final matches = <ListenerCallInfo>[];
    for (final listener in listenerProviders) {
      if (selfKey != null && listener.descriptor.key == selfKey) continue;

      final DartType? typeArg = listener.descriptor.metadata.listenerTypeArgument;
      if (_listenerMatchesType(typeArg, provisionedType)) {
        final DartType returnType = listener.descriptor.returnType;
        final DartType unwrapped = returnType.unwrapFuture;
        final String typeName = listener.descriptor.metadata.isAsynchronous && !identical(unwrapped, returnType)
            ? unwrapped.displayName
            : returnType.displayName;
        final String? qualifier = listener.descriptor.metadata.qualifier;
        final String className = ProviderGenerator.providerClassName(
          typeName,
          qualifier,
          componentPrefix: componentPrefix,
        );
        final String baseName = ProviderGenerator.providerBaseName(
          typeName,
          qualifier,
          componentPrefix: componentPrefix,
        );
        matches.add((providerClassName: className, fieldName: '_$baseName'));
      }
    }
    return matches;
  }

  /// Checks if a listener with [listenerTypeArg] should fire for
  /// [provisionedType].
  static bool _listenerMatchesType(
    DartType? listenerTypeArg,
    DartType provisionedType,
  ) {
    // Catch-all: null means Object or raw ProvisionListener
    if (listenerTypeArg == null) return true;
    // Type-specific: use isAssignableFrom for subtype matching
    if (listenerTypeArg case final InterfaceType listenerInterface) {
      return TypeChecker.fromStatic(listenerInterface).isAssignableFromType(provisionedType);
    }
    return false;
  }
}
