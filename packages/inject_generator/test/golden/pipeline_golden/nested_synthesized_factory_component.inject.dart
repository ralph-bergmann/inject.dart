// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nested_synthesized_factory_component.dart' as _i1;

class CoffeeShop$Component implements _i1.CoffeeShop {
  factory CoffeeShop$Component.create() => CoffeeShop$Component._();

  CoffeeShop$Component._() {
    final grinder$Provider = _Grinder$Provider();
    final latteFactory$Provider = _LatteFactory$Provider(grinder$Provider);
    _coffeeAppFactory$Provider = _CoffeeAppFactory$Provider(
      latteFactory$Provider,
    );
  }

  late final _CoffeeAppFactory$Provider _coffeeAppFactory$Provider;

  @override
  _i1.CoffeeAppFactory get coffeeAppFactory => _coffeeAppFactory$Provider.get();
}

class _CoffeeAppFactory$Factory implements _i1.CoffeeAppFactory {
  const _CoffeeAppFactory$Factory(this._latteFactory$Provider);

  final _LatteFactory$Provider _latteFactory$Provider;

  @override
  _i1.CoffeeApp create(int id) =>
      _i1.CoffeeApp(_latteFactory$Provider.get(), id);
}

class _CoffeeAppFactory$Provider implements _i2.Provider<_i1.CoffeeAppFactory> {
  _CoffeeAppFactory$Provider(this._latteFactory$Provider);

  final _LatteFactory$Provider _latteFactory$Provider;

  late final _i1.CoffeeAppFactory _factory = _CoffeeAppFactory$Factory(
    _latteFactory$Provider,
  );

  @override
  _i1.CoffeeAppFactory get() => _factory;
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
