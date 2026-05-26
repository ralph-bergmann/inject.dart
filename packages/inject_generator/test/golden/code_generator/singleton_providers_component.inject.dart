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

import 'singleton_providers_component.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _coffeeMaker$Provider = _CoffeeMaker$Provider(appModule);
    _databaseService$Provider = _DatabaseService$Provider(appModule);
  }

  late final _CoffeeMaker$Provider _coffeeMaker$Provider;

  late final _DatabaseService$Provider _databaseService$Provider;

  @override
  _i1.CoffeeMaker get coffeeMaker => _coffeeMaker$Provider.get();

  @override
  _i2.Future<_i1.DatabaseService> get databaseService =>
      _databaseService$Provider.get();
}

class _CoffeeMaker$Provider implements _i3.Provider<_i1.CoffeeMaker> {
  _CoffeeMaker$Provider(this._module);

  final _i1.AppModule _module;

  late final _i1.CoffeeMaker _singleton = _create();

  _i1.CoffeeMaker _create() => _module.provideCoffeeMaker();

  @override
  _i1.CoffeeMaker get() => _singleton;
}

class _DatabaseService$Provider
    implements _i3.Provider<_i2.Future<_i1.DatabaseService>> {
  _DatabaseService$Provider(this._module);

  final _i1.AppModule _module;

  _i2.Future<_i1.DatabaseService>? _singletonFuture;

  _i2.Future<_i1.DatabaseService> _create() => _module.provideDatabaseService();

  @override
  _i2.Future<_i1.DatabaseService> get() => _singletonFuture ??= _create();
}
