// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'entry_point_as_factory_dep_component.dart' as _i1;

class CoffeeShop$Component implements _i1.CoffeeShop {
  factory CoffeeShop$Component.create() => CoffeeShop$Component._();

  CoffeeShop$Component._() {
    _grinder$Provider = _Grinder$Provider();
    _latteFactory$Provider = _LatteFactory$Provider(_grinder$Provider);
  }

  late final _Grinder$Provider _grinder$Provider;

  late final _LatteFactory$Provider _latteFactory$Provider;

  @override
  _i1.Grinder get grinder => _grinder$Provider.get();

  @override
  _i1.LatteFactory get latteFactory => _latteFactory$Provider.get();
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
