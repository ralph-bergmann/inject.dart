// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'multi_qualifier_factory.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final heater$Provider = _Heater$Provider();
    _quickCoffeeMakerFactory$Provider = _QuickCoffeeMakerFactory$Provider(
      heater$Provider,
    );
    _slowCoffeeMakerFactory$Provider = _SlowCoffeeMakerFactory$Provider(
      heater$Provider,
    );
  }

  late final _QuickCoffeeMakerFactory$Provider
  _quickCoffeeMakerFactory$Provider;

  late final _SlowCoffeeMakerFactory$Provider _slowCoffeeMakerFactory$Provider;

  @override
  _i1.QuickCoffeeMakerFactory get quickCoffeeMakerFactory =>
      _quickCoffeeMakerFactory$Provider.get();

  @override
  _i1.SlowCoffeeMakerFactory get slowCoffeeMakerFactory =>
      _slowCoffeeMakerFactory$Provider.get();
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}

class _QuickCoffeeMakerFactory$Factory implements _i1.QuickCoffeeMakerFactory {
  const _QuickCoffeeMakerFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.CoffeeMaker create(String name) =>
      _i1.CoffeeMaker(_heater$Provider.get(), name);
}

class _QuickCoffeeMakerFactory$Provider
    implements _i2.Provider<_i1.QuickCoffeeMakerFactory> {
  _QuickCoffeeMakerFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.QuickCoffeeMakerFactory _factory =
      _QuickCoffeeMakerFactory$Factory(_heater$Provider);

  @override
  _i1.QuickCoffeeMakerFactory get() => _factory;
}

class _SlowCoffeeMakerFactory$Factory implements _i1.SlowCoffeeMakerFactory {
  const _SlowCoffeeMakerFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.CoffeeMaker create(String name, int timeout) =>
      _i1.CoffeeMaker.detailed(_heater$Provider.get(), name, timeout);
}

class _SlowCoffeeMakerFactory$Provider
    implements _i2.Provider<_i1.SlowCoffeeMakerFactory> {
  _SlowCoffeeMakerFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.SlowCoffeeMakerFactory _factory =
      _SlowCoffeeMakerFactory$Factory(_heater$Provider);

  @override
  _i1.SlowCoffeeMakerFactory get() => _factory;
}
