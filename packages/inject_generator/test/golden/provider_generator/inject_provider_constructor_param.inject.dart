// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'inject_provider_constructor_param.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.WaterModule? waterModule}) =>
      AppComponent$Component._(waterModule ?? _i1.WaterModule());

  AppComponent$Component._(_i1.WaterModule waterModule) {
    final heater$Provider = _Heater$Provider();
    final futureOfWater$Provider = _FutureOfWater$Provider(waterModule);
    final waterTank$Provider = _WaterTank$Provider(futureOfWater$Provider);
    _coffeeMaker$Provider = _CoffeeMaker$Provider(
      heater$Provider,
      waterTank$Provider,
    );
  }

  late final _CoffeeMaker$Provider _coffeeMaker$Provider;

  @override
  _i1.CoffeeMaker get coffeeMaker => _coffeeMaker$Provider.get();
}

class _CoffeeMaker$Provider implements _i2.Provider<_i1.CoffeeMaker> {
  const _CoffeeMaker$Provider(this._heater$Provider, this._waterTank$Provider);

  final _Heater$Provider _heater$Provider;

  final _WaterTank$Provider _waterTank$Provider;

  @override
  _i1.CoffeeMaker get() => _i1.CoffeeMaker(
    heaterProvider: _heater$Provider,
    waterTankProvider: _waterTank$Provider,
  );
}

class _FutureOfWater$Provider implements _i2.Provider<_i3.Future<_i1.Water>> {
  const _FutureOfWater$Provider(this._module);

  final _i1.WaterModule _module;

  @override
  _i3.Future<_i1.Water> get() => _module.provideWater();
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}

class _WaterTank$Provider implements _i2.Provider<_i1.WaterTank> {
  const _WaterTank$Provider(this._futureOfWater$Provider);

  final _FutureOfWater$Provider _futureOfWater$Provider;

  @override
  _i1.WaterTank get() => _i1.WaterTank(waterProvider: _futureOfWater$Provider);
}
