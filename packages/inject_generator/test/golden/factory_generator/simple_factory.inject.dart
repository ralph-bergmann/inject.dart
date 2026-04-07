// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'simple_factory.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final heater$Provider = _Heater$Provider();
    _coffeeMakerFactory$Provider = _CoffeeMakerFactory$Provider(
      heater$Provider,
    );
  }

  late final _CoffeeMakerFactory$Provider _coffeeMakerFactory$Provider;

  @override
  _i1.CoffeeMakerFactory get coffeeMakerFactory =>
      _coffeeMakerFactory$Provider.get();
}

class _CoffeeMakerFactory$Factory implements _i1.CoffeeMakerFactory {
  const _CoffeeMakerFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.CoffeeMaker create(String name) =>
      _i1.CoffeeMaker(_heater$Provider.get(), name);
}

class _CoffeeMakerFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerFactory> {
  _CoffeeMakerFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.CoffeeMakerFactory _factory = _CoffeeMakerFactory$Factory(
    _heater$Provider,
  );

  @override
  _i1.CoffeeMakerFactory get() => _factory;
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}
