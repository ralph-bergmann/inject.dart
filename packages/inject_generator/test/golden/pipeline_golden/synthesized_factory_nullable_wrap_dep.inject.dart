// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_factory_nullable_wrap_dep.dart' as _i1;

class Cafe$Component implements _i1.Cafe {
  factory Cafe$Component.create() => Cafe$Component._();

  Cafe$Component._() {
    final beans$Provider = _Beans$Provider();
    _latteFactory$Provider = _LatteFactory$Provider(beans$Provider);
    _espressoFactory$Provider = _EspressoFactory$Provider(
      beans$Provider,
      _latteFactory$Provider,
    );
  }

  late final _LatteFactory$Provider _latteFactory$Provider;

  late final _EspressoFactory$Provider _espressoFactory$Provider;

  @override
  _i1.LatteFactory get latteFactory => _latteFactory$Provider.get();

  @override
  _i1.EspressoFactory get espressoFactory => _espressoFactory$Provider.get();
}

class _Beans$Provider implements _i2.Provider<_i1.Beans> {
  const _Beans$Provider();

  @override
  _i1.Beans get() => _i1.Beans();
}

class _EspressoFactory$Factory implements _i1.EspressoFactory {
  const _EspressoFactory$Factory(
    this._beans$Provider,
    this._latteFactory$Provider,
  );

  final _Beans$Provider _beans$Provider;

  final _LatteFactory$Provider _latteFactory$Provider;

  @override
  _i1.Espresso create(int shots) =>
      _i1.Espresso(_beans$Provider.get(), _latteFactory$Provider.get(), shots);
}

class _EspressoFactory$Provider implements _i2.Provider<_i1.EspressoFactory> {
  _EspressoFactory$Provider(this._beans$Provider, this._latteFactory$Provider);

  final _Beans$Provider _beans$Provider;

  final _LatteFactory$Provider _latteFactory$Provider;

  late final _i1.EspressoFactory _factory = _EspressoFactory$Factory(
    _beans$Provider,
    _latteFactory$Provider,
  );

  @override
  _i1.EspressoFactory get() => _factory;
}

class _LatteFactory$Factory implements _i1.LatteFactory {
  const _LatteFactory$Factory(this._beans$Provider);

  final _Beans$Provider _beans$Provider;

  @override
  _i1.Latte create(String flavor) => _i1.Latte(_beans$Provider.get(), flavor);
}

class _LatteFactory$Provider implements _i2.Provider<_i1.LatteFactory> {
  _LatteFactory$Provider(this._beans$Provider);

  final _Beans$Provider _beans$Provider;

  late final _i1.LatteFactory _factory = _LatteFactory$Factory(_beans$Provider);

  @override
  _i1.LatteFactory get() => _factory;
}
