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

import 'debug_graph.dart' as _i1;

class CoffeeShop$Component implements _i1.CoffeeShop {
  factory CoffeeShop$Component.create({_i1.CoffeeModule? coffeeModule}) =>
      CoffeeShop$Component._(coffeeModule ?? _i1.CoffeeModule());

  CoffeeShop$Component._(_i1.CoffeeModule coffeeModule) {
    final heater$Provider = _Heater$Provider();
    _brewer$Provider = _Brewer$Provider(heater$Provider, coffeeModule);
    _grinder$Provider = _Grinder$Provider(heater$Provider, coffeeModule);
  }

  late final _Brewer$Provider _brewer$Provider;

  late final _Grinder$Provider _grinder$Provider;

  @override
  _i2.Future<_i1.Brewer> get brewer => _brewer$Provider.get();

  @override
  _i1.Grinder get grinder => _grinder$Provider.get();
}

class _Brewer$Provider implements _i3.Provider<_i2.Future<_i1.Brewer>> {
  _Brewer$Provider(this._heater$Provider, this._module);

  final _Heater$Provider _heater$Provider;

  final _i1.CoffeeModule _module;

  _i2.Future<_i1.Brewer>? _singletonFuture;

  _i2.Future<_i1.Brewer> _create() =>
      _module.provideBrewer(_heater$Provider.get());

  @override
  _i2.Future<_i1.Brewer> get() => _singletonFuture ??= _create();
}

class _Grinder$Provider implements _i3.Provider<_i1.Grinder> {
  const _Grinder$Provider(this._heater$Provider, this._module);

  final _Heater$Provider _heater$Provider;

  final _i1.CoffeeModule _module;

  @override
  _i1.Grinder get() => _module.provideGrinder(_heater$Provider.get());
}

class _Heater$Provider implements _i3.Provider<_i1.Heater> {
  _Heater$Provider();

  late final _i1.Heater _singleton = _create();

  _i1.Heater _create() => _i1.Heater();

  @override
  _i1.Heater get() => _singleton;
}
