// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_optional_positional.dart' as _i1;

class TeaShop$Component implements _i1.TeaShop {
  factory TeaShop$Component.create() => TeaShop$Component._();

  TeaShop$Component._() {
    final heater$Provider = _Heater$Provider();
    _teaFactory$Provider = _TeaFactory$Provider(heater$Provider);
  }

  late final _TeaFactory$Provider _teaFactory$Provider;

  @override
  _i1.TeaFactory get teaFactory => _teaFactory$Provider.get();
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}

class _TeaFactory$Factory implements _i1.TeaFactory {
  const _TeaFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.Tea create(String name, [String? suffix]) =>
      _i1.Tea(_heater$Provider.get(), name, suffix);
}

class _TeaFactory$Provider implements _i2.Provider<_i1.TeaFactory> {
  _TeaFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.TeaFactory _factory = _TeaFactory$Factory(_heater$Provider);

  @override
  _i1.TeaFactory get() => _factory;
}
