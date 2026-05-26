// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_partial_explicit.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final heater$Provider = _Heater$Provider();
    _coffeeMakerFrenchFactory$Provider = _CoffeeMakerFrenchFactory$Provider(
      heater$Provider,
    );
    _coffeeMakerStandardFactory$Provider = _CoffeeMakerStandardFactory$Provider(
      heater$Provider,
    );
  }

  late final _CoffeeMakerFrenchFactory$Provider
  _coffeeMakerFrenchFactory$Provider;

  late final _CoffeeMakerStandardFactory$Provider
  _coffeeMakerStandardFactory$Provider;

  @override
  _i1.CoffeeMakerFrenchFactory get frenchCoffeeMakerFactory =>
      _coffeeMakerFrenchFactory$Provider.get();

  @override
  _i1.CoffeeMakerStandardFactory get standardCoffeeMakerFactory =>
      _coffeeMakerStandardFactory$Provider.get();
}

class _CoffeeMakerFrenchFactory$Factory
    implements _i1.CoffeeMakerFrenchFactory {
  const _CoffeeMakerFrenchFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.CoffeeMaker create(int strength) =>
      _i1.CoffeeMaker.french(_heater$Provider.get(), strength);
}

class _CoffeeMakerFrenchFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerFrenchFactory> {
  _CoffeeMakerFrenchFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.CoffeeMakerFrenchFactory _factory =
      _CoffeeMakerFrenchFactory$Factory(_heater$Provider);

  @override
  _i1.CoffeeMakerFrenchFactory get() => _factory;
}

class _CoffeeMakerStandardFactory$Factory
    implements _i1.CoffeeMakerStandardFactory {
  const _CoffeeMakerStandardFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.CoffeeMaker create(String name) =>
      _i1.CoffeeMaker(_heater$Provider.get(), name);
}

class _CoffeeMakerStandardFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerStandardFactory> {
  _CoffeeMakerStandardFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.CoffeeMakerStandardFactory _factory =
      _CoffeeMakerStandardFactory$Factory(_heater$Provider);

  @override
  _i1.CoffeeMakerStandardFactory get() => _factory;
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}
