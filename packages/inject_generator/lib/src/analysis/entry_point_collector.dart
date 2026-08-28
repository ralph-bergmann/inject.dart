import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/binding_key.dart';
import 'type_checkers.dart';

/// A single entry point on a component or subcomponent with its full
/// binding identity.
///
/// Carries both the original `element` (getter or method) and the
/// qualifier-aware `key` so that downstream phases never need to
/// reconstruct binding identity from a raw element.
///
/// `isFuture` indicates the original return type was `Future<T>`.
/// `isProvider` indicates the original return type was `Provider<T>`.
/// Both flags can be true for `Provider<Future<T>>`.
typedef EntryPoint = ({Element element, BindingKey key, bool isFuture, bool isProvider});

/// Collects entry points from a `@component` or `@subcomponent` class.
///
/// Shared between [ComponentReader] and [SubcomponentReader] — the
/// entry-point rules are identical for both graph kinds.
class EntryPointCollector {
  /// Creates an [EntryPointCollector] reporting through [reporter].
  EntryPointCollector({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  /// Extracts `@inject`-annotated and abstract entry points (getters and
  /// methods) from [classElement].
  ///
  /// Scans the class itself and all implemented interfaces so that entry
  /// points declared on super-interfaces are picked up.
  /// Deduplication uses (member name, BindingKey) instead of member name
  /// alone so that same-named getters with different qualifiers or type
  /// identities are preserved for downstream validation and codegen,
  /// while different-named getters sharing the same BindingKey are also
  /// kept as distinct entry points.
  ///
  /// Note: The key intentionally omits isProvider/isFuture flags because
  /// Dart itself prevents same-name getters with different return types
  /// on a class or its interfaces.  Including the flags would preserve
  /// both entries and cause duplicate-getter generation in the output.
  ///
  /// The result is sorted by source offset (declaration order).
  List<EntryPoint> collectEntryPoints(ClassElement classElement) {
    final seen = <(String, BindingKey)>{};
    final entryPoints = <EntryPoint>[];

    void collectFrom(InterfaceElement element) {
      for (final GetterElement getter in element.getters) {
        // Accept entry points that are either explicitly annotated with
        // @inject or are abstract (abstract getters on a component or
        // subcomponent class are implicitly entry points — no annotation
        // needed).
        if (!injectChecker.hasAnnotationOf(getter) && !getter.isAbstract) {
          continue;
        }
        final ({bool isFuture, bool isProvider, BindingKey key})? result = _readEntryPointKey(
          getter,
          getter.returnType,
        );
        if (result == null) {
          continue;
        }
        if (seen.add((getter.name!, result.key))) {
          entryPoints.add((element: getter, key: result.key, isFuture: result.isFuture, isProvider: result.isProvider));
        }
      }
      for (final MethodElement method in element.methods) {
        // Same logic: @inject or abstract → entry point.
        if (!injectChecker.hasAnnotationOf(method) && !method.isAbstract) {
          continue;
        }
        final ({bool isFuture, bool isProvider, BindingKey key})? result = _readEntryPointKey(
          method,
          method.returnType,
        );
        if (result == null) {
          continue;
        }
        if (seen.add((method.name!, result.key))) {
          entryPoints.add((element: method, key: result.key, isFuture: result.isFuture, isProvider: result.isProvider));
        }
      }
    }

    collectFrom(classElement);
    for (final InterfaceType supertype in classElement.allSupertypes) {
      collectFrom(supertype.element);
    }

    entryPoints.sort((a, b) {
      final int offsetA = a.element.firstFragment.offset;
      final int offsetB = b.element.firstFragment.offset;
      return offsetA.compareTo(offsetB);
    });

    return entryPoints;
  }

  ({BindingKey key, bool isFuture, bool isProvider})? _readEntryPointKey(Element element, DartType returnType) {
    final String? qualifier = element.readQualifier();

    // Unwrap Provider<T> and Future<T> wrappers.
    final (:DartType resolvedType, :bool isFuture, :bool isProvider) = returnType.unwrapProviderAndFuture();

    final BindingKey? key = BindingKey.fromDartType(resolvedType, qualifier: qualifier);
    if (key != null) {
      return (key: key, isFuture: isFuture, isProvider: isProvider);
    }
    final String typeDescription = switch (resolvedType) {
      RecordType() => 'Record type',
      FunctionType() => 'Function type',
      _ => 'Unsupported type \'${resolvedType.getDisplayString()}\'',
    };
    reporter.errorForElement(
      element,
      message: '$typeDescription is not supported as a component entry point on \'${element.name ?? '<unknown>'}\'.',
      suggestion:
          'Expose an interface return type or wrap the value in a class that can participate in binding resolution.',
    );

    return null;
  }
}
