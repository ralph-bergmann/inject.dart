// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'debug_graph_multi.dart' as _i1;

class CoffeeShop$Component implements _i1.CoffeeShop {
  factory CoffeeShop$Component.create({_i1.CoffeeModule? coffeeModule}) =>
      CoffeeShop$Component._(coffeeModule ?? _i1.CoffeeModule());

  CoffeeShop$Component._(_i1.CoffeeModule coffeeModule) {
    final heater$Provider = _Heater$Provider(coffeeModule);
    _brewer$Provider = _Brewer$Provider(heater$Provider, coffeeModule);
  }

  late final _Brewer$Provider _brewer$Provider;

  @override
  _i1.Brewer get brewer => _brewer$Provider.get();
}

class TeaShop$Component implements _i1.TeaShop {
  factory TeaShop$Component.create({_i1.TeaModule? teaModule}) =>
      TeaShop$Component._(teaModule ?? _i1.TeaModule());

  TeaShop$Component._(_i1.TeaModule teaModule) {
    final kettle$Provider = _Kettle$Provider(teaModule);
    _steeper$Provider = _Steeper$Provider(kettle$Provider, teaModule);
  }

  late final _Steeper$Provider _steeper$Provider;

  @override
  _i1.Steeper get steeper => _steeper$Provider.get();
}

class _Brewer$Provider implements _i2.Provider<_i1.Brewer> {
  const _Brewer$Provider(this._heater$Provider, this._module);

  final _Heater$Provider _heater$Provider;

  final _i1.CoffeeModule _module;

  @override
  _i1.Brewer get() => _module.provideBrewer(_heater$Provider.get());
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  _Heater$Provider(this._module);

  final _i1.CoffeeModule _module;

  late final _i1.Heater _singleton = _create();

  _i1.Heater _create() => _module.provideHeater();

  @override
  _i1.Heater get() => _singleton;
}

class _Kettle$Provider implements _i2.Provider<_i1.Kettle> {
  const _Kettle$Provider(this._module);

  final _i1.TeaModule _module;

  @override
  _i1.Kettle get() => _module.provideKettle();
}

class _Steeper$Provider implements _i2.Provider<_i1.Steeper> {
  const _Steeper$Provider(this._kettle$Provider, this._module);

  final _Kettle$Provider _kettle$Provider;

  final _i1.TeaModule _module;

  @override
  _i1.Steeper get() => _module.provideSteeper(_kettle$Provider.get());
}
