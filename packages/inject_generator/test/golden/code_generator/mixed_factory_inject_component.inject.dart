// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'mixed_factory_inject_component.dart' as _i1;

class CoffeeShop$Component implements _i1.CoffeeShop {
  factory CoffeeShop$Component.create() => CoffeeShop$Component._();

  CoffeeShop$Component._() {
    final heater$Provider = _Heater$Provider();
    final grinder$Provider = _Grinder$Provider();
    _coffeeMaker$Provider = _CoffeeMaker$Provider(
      heater$Provider,
      grinder$Provider,
    );
    _latteFactory$Provider = _LatteFactory$Provider(grinder$Provider);
  }

  late final _CoffeeMaker$Provider _coffeeMaker$Provider;

  late final _LatteFactory$Provider _latteFactory$Provider;

  @override
  _i1.CoffeeMaker get coffeeMaker => _coffeeMaker$Provider.get();

  @override
  _i1.LatteFactory get latteFactory => _latteFactory$Provider.get();
}

class _CoffeeMaker$Provider implements _i2.Provider<_i1.CoffeeMaker> {
  const _CoffeeMaker$Provider(this._heater$Provider, this._grinder$Provider);

  final _Heater$Provider _heater$Provider;

  final _Grinder$Provider _grinder$Provider;

  @override
  _i1.CoffeeMaker get() =>
      _i1.CoffeeMaker(_heater$Provider.get(), _grinder$Provider.get());
}

class _Grinder$Provider implements _i2.Provider<_i1.Grinder> {
  const _Grinder$Provider();

  @override
  _i1.Grinder get() => _i1.Grinder();
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}

class _LatteFactory$Factory implements _i1.LatteFactory {
  const _LatteFactory$Factory(this._grinder$Provider);

  final _Grinder$Provider _grinder$Provider;

  @override
  _i1.Latte create(String name) => _i1.Latte(_grinder$Provider.get(), name);
}

class _LatteFactory$Provider implements _i2.Provider<_i1.LatteFactory> {
  _LatteFactory$Provider(this._grinder$Provider);

  final _Grinder$Provider _grinder$Provider;

  late final _i1.LatteFactory _factory = _LatteFactory$Factory(
    _grinder$Provider,
  );

  @override
  _i1.LatteFactory get() => _factory;
}
