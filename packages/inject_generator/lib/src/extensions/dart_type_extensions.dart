import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart' hide FunctionType;

import 'element_extensions.dart';

/// Code-generation helpers on [DartType]: display names and [Reference] construction.
extension DartTypeExt on DartType {
  /// Returns the display name for a [DartType] suitable for use in
  /// generated identifiers.
  ///
  /// Includes generic type arguments to prevent collisions between
  /// types like `List<int>` and `List<String>`.
  /// Supports typedef'd types (FunctionType, RecordType) via the type's alias.
  String get displayName {
    final type = this;
    if (type case InterfaceType()) {
      final String baseName = type.element.name!;
      final List<DartType> typeArgs = type.typeArguments;
      final nullableSuffix = type.nullabilitySuffix == NullabilitySuffix.question ? 'Nullable' : '';
      if (typeArgs.isEmpty) {
        return '$baseName$nullableSuffix';
      }
      final String argNames = typeArgs
          .map((t) {
            final String n = t.displayName;
            return n.isEmpty ? n : '${n[0].toUpperCase()}${n.substring(1)}';
          })
          .join('And');
      return '${baseName}Of$argNames$nullableSuffix';
    }
    // Typedef'd type (function or record): use alias name and type arguments
    if (type.alias case final alias?) {
      final String baseName = alias.element.name!;
      final List<DartType> typeArgs = alias.typeArguments;
      if (typeArgs.isEmpty) {
        return baseName;
      }
      final String argNames = typeArgs
          .map((t) {
            final String n = t.displayName;
            return n.isEmpty ? n : '${n[0].toUpperCase()}${n.substring(1)}';
          })
          .join('And');
      return '${baseName}Of$argNames';
    }
    final String display = type.getDisplayString();
    return display.endsWith('?') ? '${display.substring(0, display.length - 1)}Nullable' : display;
  }

  /// Like [displayName] but always omits the nullability suffix.
  ///
  /// Use this for provider field names and provider class names: the provider
  /// for `Foo?` is the same object as for `Foo` (nullable-widening), so both
  /// must resolve to the same identifier (`_Foo$Provider`).
  String get nonNullableDisplayName {
    final type = this;
    if (type case InterfaceType()) {
      final String baseName = type.element.name!;
      final List<DartType> typeArgs = type.typeArguments;
      if (typeArgs.isEmpty) {
        return baseName;
      }
      final String argNames = typeArgs
          .map((t) {
            final String n = t.displayName;
            return n.isEmpty ? n : '${n[0].toUpperCase()}${n.substring(1)}';
          })
          .join('And');
      return '${baseName}Of$argNames';
    }
    // For typedef/alias types nullability suffix is never emitted in displayName anyway
    if (type.alias != null) {
      return displayName;
    }
    final String display = type.getDisplayString();
    return display.endsWith('?') ? display.substring(0, display.length - 1) : display;
  }

  /// Creates a [Reference] for the given [DartType], optionally resolving
  /// import URIs relative to [sourceUri].
  /// Supports typedef'd types (FunctionType, RecordType) via the type's alias.
  Reference typeRef({String? sourceUri}) => _buildTypeRef(false, sourceUri: sourceUri);

  /// Like [typeRef] but forces the resulting reference to be nullable.
  Reference nullableTypeRef({String? sourceUri}) => _buildTypeRef(true, sourceUri: sourceUri);

  /// Creates a `Future<T>` reference wrapping this type.
  TypeReference futureTypeRef({String? sourceUri}) => TypeReference(
    (b) => b
      ..symbol = 'Future'
      ..url = 'dart:async'
      ..types.add(typeRef(sourceUri: sourceUri)),
  );

  /// Creates a `Provider<T>` type reference.
  TypeReference providerTypeRef({String? sourceUri, bool partFileContext = false}) => TypeReference(
    (b) => b
      ..symbol = 'Provider'
      ..url = partFileContext ? null : 'package:inject_annotation/inject_annotation.dart'
      ..types.add(typeRef(sourceUri: sourceUri)),
  );

  Reference _buildTypeRef(bool forceNullable, {String? sourceUri}) {
    final type = this;
    if (type case InterfaceType()) {
      final InterfaceElement element = type.element;
      final List<DartType> typeArgs = type.typeArguments;
      return TypeReference(
        (b) => b
          ..symbol = element.name
          ..url = sourceUri != null ? element.resolvePublicUri(sourceUri: sourceUri) : null
          ..isNullable = forceNullable || type.nullabilitySuffix == NullabilitySuffix.question
          ..types.addAll(typeArgs.map((t) => t.typeRef(sourceUri: sourceUri))),
      );
    }
    if (type.alias case final alias?) {
      final TypeAliasElement element = alias.element;
      return TypeReference(
        (b) => b
          ..symbol = element.name
          ..url = sourceUri != null ? element.resolvePublicUri(sourceUri: sourceUri) : null
          ..isNullable = forceNullable || type.nullabilitySuffix == NullabilitySuffix.question
          ..types.addAll(alias.typeArguments.map((t) => t.typeRef(sourceUri: sourceUri))),
      );
    }
    final String raw = type.getDisplayString();
    final String display = raw.endsWith('?') ? raw.substring(0, raw.length - 1) : raw;
    final bool isNullable = forceNullable || type.nullabilitySuffix == NullabilitySuffix.question;
    return refer(isNullable ? '$display?' : display);
  }

  /// Whether this type is `ViewModelFactory<T>` from `inject_flutter`.
  bool get isViewModelFactory {
    final InstantiatedTypeAliasElement? alias = this.alias;
    if (alias == null) return false;
    return alias.element.name == 'ViewModelFactory' &&
        alias.element.library.uri.toString() == 'package:inject_flutter/src/view_model_factory.dart';
  }
}

/// Result of unwrapping `Provider<T>` and `Future<T>` from a type.
typedef UnwrapResult = ({DartType resolvedType, bool isFuture, bool isProvider});

/// Helpers for unwrapping `Provider<T>` and `Future<T>` wrappers from a type.
extension FutureUnwrapExt on DartType {
  /// Returns the inner type if this is `Future<T>`, otherwise returns `this`.
  DartType get unwrapFuture => switch (this) {
    InterfaceType(:final isDartAsyncFuture, typeArguments: [final inner]) when isDartAsyncFuture => inner,
    _ => this,
  };

  /// Unwraps `Provider<T>` then `Future<T>`, tracking which wrappers were present.
  UnwrapResult unwrapProviderAndFuture() {
    var isProvider = false;
    var resolvedType = this;

    if (resolvedType
        case InterfaceType(
          element: final el,
          typeArguments: [final inner],
        )
        when el.name == 'Provider' && el.library.identifier.startsWith('package:inject_annotation/')) {
      isProvider = true;
      resolvedType = inner;
    }

    var isFuture = false;
    final DartType unwrapped = resolvedType.unwrapFuture;
    if (!identical(unwrapped, resolvedType)) {
      isFuture = true;
      resolvedType = unwrapped;
    }

    return (resolvedType: resolvedType, isFuture: isFuture, isProvider: isProvider);
  }

  /// Returns the inner type and `true` if this is a `Provider<T>` from
  /// inject_annotation; otherwise returns this type unchanged with `false`.
  ///
  /// Unlike [unwrapProviderAndFuture] this unwraps **only** the `Provider`
  /// wrapper, never `Future`, so a raw `Future<T>` parameter stays intact as a
  /// raw-future binding.
  ({DartType type, bool isProvider}) unwrapProviderParam() => switch (this) {
    InterfaceType(element: final el, typeArguments: [final inner])
        when el.name == 'Provider' && el.library.identifier.startsWith('package:inject_annotation/') =>
      (type: inner, isProvider: true),
    _ => (type: this, isProvider: false),
  };
}
