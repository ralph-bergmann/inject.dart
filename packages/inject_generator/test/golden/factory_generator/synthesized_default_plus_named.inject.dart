// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_default_plus_named.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final heater$Provider = _Heater$Provider();
    _coffeeMakerDetailFactory$Provider = _CoffeeMakerDetailFactory$Provider(
      heater$Provider,
    );
    _coffeeMakerStandardFactory$Provider = _CoffeeMakerStandardFactory$Provider(
      heater$Provider,
    );
  }

  late final _CoffeeMakerDetailFactory$Provider
  _coffeeMakerDetailFactory$Provider;

  late final _CoffeeMakerStandardFactory$Provider
  _coffeeMakerStandardFactory$Provider;

  @override
  _i1.CoffeeMakerDetailFactory get detailCoffeeMakerFactory =>
      _coffeeMakerDetailFactory$Provider.get();

  @override
  _i1.CoffeeMakerStandardFactory get standardCoffeeMakerFactory =>
      _coffeeMakerStandardFactory$Provider.get();
}

class _CoffeeMakerDetailFactory$Factory
    implements _i1.CoffeeMakerDetailFactory {
  const _CoffeeMakerDetailFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.CoffeeMaker create(int strength) =>
      _i1.CoffeeMaker.detail(_heater$Provider.get(), strength);
}

class _CoffeeMakerDetailFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerDetailFactory> {
  _CoffeeMakerDetailFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.CoffeeMakerDetailFactory _factory =
      _CoffeeMakerDetailFactory$Factory(_heater$Provider);

  @override
  _i1.CoffeeMakerDetailFactory get() => _factory;
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
