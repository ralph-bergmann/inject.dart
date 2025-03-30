// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

import '../analyzer/utils.dart';
import '../build/codegen_builder.dart';
import 'symbol_path.dart';

part 'lookup_key.g.dart';

const _listEquality = ListEquality();

/// A representation of a key in the dependency injection graph.
///
/// Equality of all the fields indicate that two types are the same.
@JsonSerializable()
class LookupKey {
  /// [SymbolPath] of the root type.
  ///
  /// For example, for the type `@qualifier A<B, C>`, this will be `A`.
  final SymbolPath root;

  /// Optional qualifier to distinguish between different instances of the same type
  final SymbolPath? qualifier;

  /// Type arguments for generic types, where each argument is a complete LookupKey
  /// Example: For `List<Map<String, int>>`, this would contain a LookupKey for `Map<String, int>`
  final List<LookupKey>? typeArguments;

  /// The bound for type parameters (e.g., `T extends Comparable<T>`)
  final LookupKey? bound;

  const LookupKey(this.root, {this.qualifier, this.typeArguments, this.bound});

  factory LookupKey.fromJson(Map<String, dynamic> json) => _$LookupKeyFromJson(json);

  /// Creates a LookupKey from a DartType
  factory LookupKey.fromDartType(DartType type, {SymbolPath? qualifier}) {
    // Helper to extract LookupKeys for the type arguments of a bound.
    List<LookupKey> extractBoundTypes(DartType t) {
      if (t is ParameterizedType && t.typeArguments.isNotEmpty) {
        return t.typeArguments
            .map(
              (arg) => LookupKey(
                getSymbolPath(arg),
                // Recurse using the default constructor to avoid infinite recursion.
                typeArguments: extractBoundTypes(arg),
              ),
            )
            .toList();
      }
      return [];
    }

    if (type is RecordType && type.alias == null) {
      throw UnsupportedError('Record types are not supported for injection. '
          'Please define a typedef for your record type to provide a stable name.');
    }

    if (type is FunctionType && type.alias == null) {
      throw UnsupportedError(
          'Function types cannot be directly used for dependency injection because they lack a stable, canonical name. '
          'Please define a typedef for your function type and use that typedef instead.');
    }

    if (type is TypeParameterType) {
      final boundType = type.bound;
      LookupKey? bound;
      if (boundType is ParameterizedType) {
        final boundTypeArgs = extractBoundTypes(boundType);
        bound = LookupKey(
          getSymbolPath(boundType),
          // If there are no type arguments, set to null.
          typeArguments: boundTypeArgs.isEmpty ? null : boundTypeArgs,
        );
      } else {
        bound = LookupKey(getSymbolPath(boundType));
      }
      return LookupKey(
        getSymbolPath(type),
        qualifier: qualifier,
        bound: bound,
      );
    }

    if (type is ParameterizedType && type.typeArguments.isNotEmpty || type.alias != null) {
      return LookupKey(
        getSymbolPath(type),
        qualifier: qualifier,
        typeArguments: type.allTypeArguments?.map(LookupKey.fromDartType).toList(),
      );
    }
    return LookupKey(getSymbolPath(type), qualifier: qualifier);
  }

  /// A human-readable representation of the dart Symbol of this type.
  String toPrettyString() {
    final qualifierString = qualifier != null ? '${qualifier!.symbol}@' : '';
    final typeArgumentsString =
        typeArguments?.isNotEmpty == true ? '<${typeArguments!.map((e) => e.toPrettyString()).join(', ')}>' : '';
    final boundString = bound != null ? ' extends ${bound!.toPrettyString()}' : '';
    return '$qualifierString${root.symbol}$typeArgumentsString$boundString';
  }

  /// A representation of the dart Symbol of this type to be used in generated code as class name.
  /// For example, for the type `@qualifier A<B, C>`, this will be `ABC`.
  String toClassName() {
    final rootString = root.symbol.capitalize();
    final qualifierString = qualifier != null ? qualifier!.symbol.capitalize() : '';
    final typeArgumentsString = typeArguments?.map((e) => e.toClassName()).join() ?? '';
    final boundString = bound != null ? bound!.toClassName() : '';
    return '$rootString$qualifierString$typeArgumentsString$boundString';
  }

  LookupKey toFeature() {
    if (root == SymbolPath.feature) {
      return this;
    }

    return LookupKey(
      SymbolPath.feature,
      qualifier: qualifier,
      typeArguments: [this],
    );
  }

  Map<String, dynamic> toJson() => _$LookupKeyToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookupKey &&
          runtimeType == other.runtimeType &&
          root == other.root &&
          qualifier == other.qualifier &&
          _listEquality.equals(typeArguments, other.typeArguments) &&
          bound == other.bound;

  @override
  int get hashCode => Object.hash(
        root,
        qualifier,
        _listEquality.hash(typeArguments),
        bound,
      );
}

extension _TypeArgumentExtension on DartType {
  List<DartType>? get allTypeArguments => _getTypeArguments(this);
}

/// Gets the type arguments from a DartType, handling both regular types and typedefs
List<DartType>? _getTypeArguments(DartType type) {
  if (type.alias != null) {
    // Case 1: It's a typedef (has an alias)
    final alias = type.alias!;

    // If it's a parameterized typedef (like ViewModelFactory<T>)
    if (alias.typeArguments.isNotEmpty) {
      return alias.typeArguments;
    }
  } else if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
    // Case 2: It's a regular parameterized type
    return type.typeArguments;
  }

  // No type arguments found
  return null;
}
