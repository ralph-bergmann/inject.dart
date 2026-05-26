// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_multi_ctor_nullable_factory_dep.dart' as _i1;

class CoffeeShop$Component implements _i1.CoffeeShop {
  factory CoffeeShop$Component.create() => CoffeeShop$Component._();

  CoffeeShop$Component._() {
    final grinder$Provider = _Grinder$Provider();
    _latteFactory$Provider = _LatteFactory$Provider(grinder$Provider);
    _coffeeMakerFancyFactory$Provider = _CoffeeMakerFancyFactory$Provider(
      grinder$Provider,
      _latteFactory$Provider,
    );
    _coffeeMakerStandardFactory$Provider = _CoffeeMakerStandardFactory$Provider(
      grinder$Provider,
    );
  }

  late final _LatteFactory$Provider _latteFactory$Provider;

  late final _CoffeeMakerFancyFactory$Provider
  _coffeeMakerFancyFactory$Provider;

  late final _CoffeeMakerStandardFactory$Provider
  _coffeeMakerStandardFactory$Provider;

  @override
  _i1.LatteFactory get latteFactory => _latteFactory$Provider.get();

  @override
  _i1.CoffeeMakerFancyFactory get fancyFactory =>
      _coffeeMakerFancyFactory$Provider.get();

  @override
  _i1.CoffeeMakerStandardFactory get standardFactory =>
      _coffeeMakerStandardFactory$Provider.get();
}

class _CoffeeMakerFancyFactory$Factory implements _i1.CoffeeMakerFancyFactory {
  const _CoffeeMakerFancyFactory$Factory(
    this._grinder$Provider,
    this._latteFactory$Provider,
  );

  final _Grinder$Provider _grinder$Provider;

  final _LatteFactory$Provider _latteFactory$Provider;

  @override
  _i1.CoffeeMaker create(int beans) => _i1.CoffeeMaker.fancy(
    _grinder$Provider.get(),
    _latteFactory$Provider.get(),
    beans,
  );
}

class _CoffeeMakerFancyFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerFancyFactory> {
  _CoffeeMakerFancyFactory$Provider(
    this._grinder$Provider,
    this._latteFactory$Provider,
  );

  final _Grinder$Provider _grinder$Provider;

  final _LatteFactory$Provider _latteFactory$Provider;

  late final _i1.CoffeeMakerFancyFactory _factory =
      _CoffeeMakerFancyFactory$Factory(
        _grinder$Provider,
        _latteFactory$Provider,
      );

  @override
  _i1.CoffeeMakerFancyFactory get() => _factory;
}

class _CoffeeMakerStandardFactory$Factory
    implements _i1.CoffeeMakerStandardFactory {
  const _CoffeeMakerStandardFactory$Factory(this._grinder$Provider);

  final _Grinder$Provider _grinder$Provider;

  @override
  _i1.CoffeeMaker create(int beans) =>
      _i1.CoffeeMaker(_grinder$Provider.get(), beans);
}

class _CoffeeMakerStandardFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerStandardFactory> {
  _CoffeeMakerStandardFactory$Provider(this._grinder$Provider);

  final _Grinder$Provider _grinder$Provider;

  late final _i1.CoffeeMakerStandardFactory _factory =
      _CoffeeMakerStandardFactory$Factory(_grinder$Provider);

  @override
  _i1.CoffeeMakerStandardFactory get() => _factory;
}

class _Grinder$Provider implements _i2.Provider<_i1.Grinder> {
  const _Grinder$Provider();

  @override
  _i1.Grinder get() => _i1.Grinder();
}

class _LatteFactory$Factory implements _i1.LatteFactory {
  const _LatteFactory$Factory(this._grinder$Provider);

  final _Grinder$Provider _grinder$Provider;

  @override
  _i1.Latte create(String flavor) => _i1.Latte(_grinder$Provider.get(), flavor);
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
