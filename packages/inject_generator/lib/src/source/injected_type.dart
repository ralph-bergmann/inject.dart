// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'lookup_key.dart';

part 'injected_type.g.dart';

/// A type that the user is trying to inject with associated metadata about how
/// the user is trying to inject it.
@JsonSerializable()
class InjectedType {
  /// The type the user is trying to inject.
  final LookupKey lookupKey;

  /// Name of the parameter.
  final String? name;

  /// Return `true` if this parameter is nullable.
  final bool isNullable;

  /// Return `true` if this parameter is required.
  final bool isRequired;

  /// Return `true` if it is a named parameter. Otherwise `false` for a positional parameter.
  final bool isNamed;

  /// True if the user is trying to inject [LookupKey] using [Provider]. If
  /// false, the user is trying to inject the type directly.
  final bool isProvider;

  /// Return `true` if it is annotated with [singleton]
  final bool isSingleton;

  /// Return `true` if it is annotated with [asynchronous] or
  /// [LookupKey] is wrapped with a [Feature].
  final bool isAsynchronous;

  /// Return `true` if it is annotated with [assistedInject]
  final bool isAssisted;

  /// Return `true` if its constructor is a const constructor
  final bool isConst;

  /// True if the user is trying to inject [LookupKey] as ViewModel
  /// (a class extending Flutter's `ChangeNotifier`) using `ViewModelFactory`
  /// from package:inject_flutter.
  final bool isViewModelFactory;

  factory InjectedType(
    LookupKey lookupKey, {
    String? name,
    bool? isNullable,
    bool? isRequired,
    bool? isNamed,
    bool? isProvider,
    bool? isSingleton,
    bool? isAsynchronous,
    bool? isAssisted,
    bool? isConst,
    bool? isViewModelFactory,
  }) =>
      InjectedType._(
        lookupKey: lookupKey,
        name: name,
        isNullable: isNullable ?? false,
        isRequired: isRequired ?? false,
        isNamed: isNamed ?? false,
        isProvider: isProvider ?? false,
        isSingleton: isSingleton ?? false,
        isAsynchronous: isAsynchronous ?? false,
        isAssisted: isAssisted ?? false,
        isConst: isConst ?? false,
        isViewModelFactory: isViewModelFactory ?? false,
      );

  const InjectedType._({
    required this.lookupKey,
    required this.name,
    required this.isNullable,
    required this.isRequired,
    required this.isNamed,
    required this.isProvider,
    required this.isSingleton,
    required this.isAsynchronous,
    required this.isAssisted,
    required this.isConst,
    required this.isViewModelFactory,
  });

  factory InjectedType.fromJson(Map<String, dynamic> json) => _$InjectedTypeFromJson(json);

  Map<String, dynamic> toJson() => _$InjectedTypeToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InjectedType &&
          runtimeType == other.runtimeType &&
          lookupKey == other.lookupKey &&
          name == other.name &&
          isNullable == other.isNullable &&
          isRequired == other.isRequired &&
          isNamed == other.isNamed &&
          isProvider == other.isProvider &&
          isSingleton == other.isSingleton &&
          isAsynchronous == other.isAsynchronous &&
          isAssisted == other.isAssisted &&
          isConst == other.isConst &&
          isViewModelFactory == other.isViewModelFactory;

  @override
  int get hashCode =>
      lookupKey.hashCode ^
      name.hashCode ^
      isNullable.hashCode ^
      isRequired.hashCode ^
      isNamed.hashCode ^
      isProvider.hashCode ^
      isSingleton.hashCode ^
      isAsynchronous.hashCode ^
      isAssisted.hashCode ^
      isConst.hashCode ^
      isViewModelFactory.hashCode;
}
