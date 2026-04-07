// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'inject_multi_deps.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.CoffeeMakerModule? coffeeMakerModule,
  }) => AppComponent$Component._(coffeeMakerModule ?? _i1.CoffeeMakerModule());

  AppComponent$Component._(_i1.CoffeeMakerModule coffeeMakerModule) {
    final heater$Provider = _Heater$Provider();
    final pump$Provider = _Pump$Provider();
    _coffeeMakerBrandNameA$Provider = _CoffeeMakerBrandNameA$Provider(
      heater$Provider,
      pump$Provider,
      coffeeMakerModule,
    );
    final coffeeMakerBrandNameB$Provider = _CoffeeMakerBrandNameB$Provider(
      heater$Provider,
      pump$Provider,
      coffeeMakerModule,
    );
  }

  late final _CoffeeMakerBrandNameA$Provider _coffeeMakerBrandNameA$Provider;

  @override
  _i1.CoffeeMaker get coffeeMaker => _coffeeMakerBrandNameA$Provider.get();
}

class _CoffeeMakerBrandNameA$Provider implements _i2.Provider<_i1.CoffeeMaker> {
  const _CoffeeMakerBrandNameA$Provider(
    this._heater$Provider,
    this._pump$Provider,
    this._module,
  );

  final _Heater$Provider _heater$Provider;

  final _Pump$Provider _pump$Provider;

  final _i1.CoffeeMakerModule _module;

  @override
  _i1.CoffeeMaker get() =>
      _module.provideCoffeeMakerA(_heater$Provider.get(), _pump$Provider.get());
}

class _CoffeeMakerBrandNameB$Provider implements _i2.Provider<_i1.CoffeeMaker> {
  const _CoffeeMakerBrandNameB$Provider(
    this._heater$Provider,
    this._pump$Provider,
    this._module,
  );

  final _Heater$Provider _heater$Provider;

  final _Pump$Provider _pump$Provider;

  final _i1.CoffeeMakerModule _module;

  @override
  _i1.CoffeeMaker get() =>
      _module.provideCoffeeMakerB(_heater$Provider.get(), _pump$Provider.get());
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}

class _Pump$Provider implements _i2.Provider<_i1.Pump> {
  const _Pump$Provider();

  @override
  _i1.Pump get() => _i1.Pump();
}
