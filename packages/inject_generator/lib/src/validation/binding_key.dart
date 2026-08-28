import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// A semantically unique key for binding identity in the dependency graph.
///
/// Two bindings are considered identical when they have the same
/// [_normalizedTypeIdentity] (derived from the library URI, canonical type
/// name, recursive generic arguments, and nullability) **and** the same
/// [qualifier].
///
/// This avoids display-name collisions where same-named types from different
/// libraries would incorrectly collapse into one lookup entry.
class BindingKey {
  const BindingKey._(this._normalizedTypeIdentity, {required this.isNullable, this.qualifier});
  final String _normalizedTypeIdentity;

  /// The optional qualifier symbol name that distinguishes this binding.
  final String? qualifier;

  /// Whether this key represents a top-level nullable type (e.g. `Foo?`).
  ///
  /// Cached at construction from the source [DartType.nullabilitySuffix],
  /// independent of the identity-string encoding.
  final bool isNullable;

  /// The normalized type identity without qualifier, useful for comparing
  /// whether two keys differ only in their qualifier or also in their type.
  String get typeIdentity => _normalizedTypeIdentity;

  /// Returns a key with top-level nullability stripped.
  ///
  /// Use for nullable-widening fallback: when `Foo?` is not bound but `Foo` is,
  /// the non-nullable provider can satisfy a nullable dep (Dart allows widening).
  BindingKey get nonNullable {
    assert(isNullable, 'nonNullable called on a non-nullable BindingKey');
    return BindingKey._(
      _normalizedTypeIdentity.substring(0, _normalizedTypeIdentity.length - 1),
      isNullable: false,
      qualifier: qualifier,
    );
  }

  /// Returns a key with top-level nullability added.
  ///
  /// Mirror of [nonNullable]: used to look up the nullable counterpart of a
  /// non-nullable key in O(1) (qualifier preserved).
  BindingKey get toNullable {
    assert(!isNullable, 'toNullable called on a nullable BindingKey');
    return BindingKey._(
      '$_normalizedTypeIdentity?',
      isNullable: true,
      qualifier: qualifier,
    );
  }

  /// Builds a [BindingKey] from a [DartType].
  ///
  /// Supports [InterfaceType] (classes, enums, mixins) and typedef'd
  /// [FunctionType] (via the type's [DartType.alias]).
  ///
  /// Returns `null` for unsupported type shapes (records, extension types,
  /// non-typedef function types, raw generics). The caller is responsible
  /// for reporting unsupported-type diagnostics.
  ///
  /// The [maxDepth] parameter guards against endless recursion in deeply
  /// nested or self-referential generic type arguments.
  static BindingKey? fromDartType(DartType dartType, {String? qualifier, int maxDepth = 20}) {
    if (dartType is InterfaceType) {
      final ({String identity, bool isNullable})? result = _buildIdentity(dartType, depth: 0, maxDepth: maxDepth);
      if (result == null) {
        return null;
      }
      return BindingKey._(result.identity, isNullable: result.isNullable, qualifier: qualifier);
    }

    // Typedef'd types (e.g. ViewModelFactory<T>, MyRecord): use the alias
    // element's library URI, name, and type arguments for identity.
    // Covers both FunctionType and RecordType when wrapped in a typedef.
    final InstantiatedTypeAliasElement? alias = dartType.alias;
    if (alias != null) {
      final ({String identity, bool isNullable})? result = _buildAliasIdentity(
        alias,
        dartType.nullabilitySuffix,
        depth: 0,
        maxDepth: maxDepth,
      );
      if (result == null) {
        return null;
      }
      return BindingKey._(result.identity, isNullable: result.isNullable, qualifier: qualifier);
    }

    return null;
  }

  static ({String identity, bool isNullable})? _buildIdentity(
    InterfaceType interfaceType, {
    required int depth,
    required int maxDepth,
  }) {
    if (depth >= maxDepth) {
      return null;
    }

    final InterfaceElement element = interfaceType.element;
    final String libraryUri = element.library.identifier;
    final String? typeName = element.name;
    final NullabilitySuffix nullability = interfaceType.nullabilitySuffix;
    final bool isNullable = nullability == NullabilitySuffix.question;

    final buffer = StringBuffer()
      ..write(libraryUri)
      ..write('#')
      ..write(typeName);

    final List<DartType> typeArgs = interfaceType.typeArguments;
    if (typeArgs.isNotEmpty) {
      buffer.write('<');
      for (var i = 0; i < typeArgs.length; i++) {
        if (i > 0) {
          buffer.write(',');
        }
        final String? argIdentity = _typeArgIdentity(typeArgs[i], depth: depth + 1, maxDepth: maxDepth);
        if (argIdentity == null) {
          return null;
        }
        buffer.write(argIdentity);
      }
      buffer.write('>');
    }

    if (isNullable) {
      buffer.write('?');
    }

    return (identity: buffer.toString(), isNullable: isNullable);
  }

  /// Builds a normalized identity string from a typedef alias.
  ///
  /// Uses the typedef element's library URI, name, and type arguments,
  /// producing the same format as [_buildIdentity] for consistency.
  static ({String identity, bool isNullable})? _buildAliasIdentity(
    InstantiatedTypeAliasElement alias,
    NullabilitySuffix nullability, {
    required int depth,
    required int maxDepth,
  }) {
    if (depth >= maxDepth) {
      return null;
    }

    final TypeAliasElement element = alias.element;
    final String libraryUri = element.library.identifier;
    final String? typeName = element.name;
    final bool isNullable = nullability == NullabilitySuffix.question;

    final buffer = StringBuffer()
      ..write(libraryUri)
      ..write('#')
      ..write(typeName);

    final List<DartType> typeArgs = alias.typeArguments;
    if (typeArgs.isNotEmpty) {
      buffer.write('<');
      for (var i = 0; i < typeArgs.length; i++) {
        if (i > 0) {
          buffer.write(',');
        }
        final String? argIdentity = _typeArgIdentity(typeArgs[i], depth: depth + 1, maxDepth: maxDepth);
        if (argIdentity == null) {
          return null;
        }
        buffer.write(argIdentity);
      }
      buffer.write('>');
    }

    if (isNullable) {
      buffer.write('?');
    }

    return (identity: buffer.toString(), isNullable: isNullable);
  }

  /// Resolves an identity string for a type argument, supporting
  /// [InterfaceType], typedef'd [FunctionType], and concrete types
  /// like `void`, `dynamic`, `Never`. Inner nullability is preserved in
  /// the returned string but does not contribute to the top-level
  /// [isNullable] flag.
  static String? _typeArgIdentity(DartType arg, {required int depth, required int maxDepth}) {
    if (arg case final InterfaceType argInterface) {
      return _buildIdentity(argInterface, depth: depth, maxDepth: maxDepth)?.identity;
    } else if (arg.alias != null) {
      // Typedef'd types (FunctionType or RecordType with alias)
      return _buildAliasIdentity(arg.alias!, arg.nullabilitySuffix, depth: depth, maxDepth: maxDepth)?.identity;
    } else if (arg is VoidType || arg is DynamicType || arg is NeverType) {
      return arg.getDisplayString();
    }
    // Unsupported type argument (non-typedef FunctionType, non-typedef RecordType, TypeParameterType, etc.)
    return null;
  }

  /// A human-readable label for diagnostic messages.
  ///
  /// Uses the type's display string rather than the normalized identity,
  /// making error messages easier to understand.
  String get debugLabel {
    // Strip all library URI prefixes from the normalized identity.
    // Format is "libraryUri#TypeName<libraryUri#ArgType,...>"
    // so we remove every "segment#" prefix to get just type names.
    final String cleaned = _normalizedTypeIdentity.replaceAll(RegExp(r'[^<>,?]+#'), '');

    if (qualifier != null) {
      return '$cleaned (#$qualifier)';
    }
    return cleaned;
  }

  /// The bare type name without qualifier suffix, for use as a tree-node label.
  ///
  /// Unlike [debugLabel], this strips only library-URI prefixes and never
  /// appends `(#qualifier)`. Used by `GraphPrinter` for `<TypeName>...`
  /// shared-node references and as the base for [formattedLabel].
  String get typeNameOnly => _normalizedTypeIdentity.replaceAll(RegExp(r'[^<>,?]+#'), '');

  /// Formats a full tree-node label in the `@`-annotation style.
  ///
  /// Annotation order: qualifier, singleton, async, injected by.
  /// Parentheses are omitted when no annotations are present.
  ///
  /// [receivers] is the alphabetically-sorted list of receiver names for the
  /// `injected by:` annotation; pass `null` to omit the annotation entirely.
  String formattedLabel({
    bool isSingleton = false,
    bool isAsync = false,
    List<String>? receivers,
  }) {
    final typeName = typeNameOnly;

    final parts = <String>[
      if (qualifier != null) '@$qualifier',
      if (isSingleton) '@singleton',
      if (isAsync) '@async',
      if (receivers != null && receivers.isNotEmpty) 'injected by: ${receivers.join(', ')}',
    ];

    if (parts.isEmpty) return typeName;
    return '$typeName (${parts.join(', ')})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BindingKey && _normalizedTypeIdentity == other._normalizedTypeIdentity && qualifier == other.qualifier;

  @override
  int get hashCode => Object.hash(_normalizedTypeIdentity, qualifier);

  @override
  String toString() => 'BindingKey($debugLabel)';
}
