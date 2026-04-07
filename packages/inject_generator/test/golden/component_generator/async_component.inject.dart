// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i2;

import 'package:inject_annotation/inject_annotation.dart' as _i3;

import 'async_component.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.DatabaseModule? databaseModule}) =>
      AppComponent$Component._(databaseModule ?? _i1.DatabaseModule());

  AppComponent$Component._(_i1.DatabaseModule databaseModule) {
    _databaseService$Provider = _DatabaseService$Provider(databaseModule);
  }

  late final _DatabaseService$Provider _databaseService$Provider;

  @override
  _i2.Future<_i1.DatabaseService> get databaseService =>
      _databaseService$Provider.get();
}

class _DatabaseService$Provider
    implements _i3.Provider<_i2.Future<_i1.DatabaseService>> {
  _DatabaseService$Provider(this._module);

  final _i1.DatabaseModule _module;

  _i2.Future<_i1.DatabaseService>? _singletonFuture;

  _i2.Future<_i1.DatabaseService> _create() => _module.provideDatabaseService();

  @override
  _i2.Future<_i1.DatabaseService> get() => _singletonFuture ??= _create();
}
