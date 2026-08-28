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
    final coffeeShop$heater$Provider = _CoffeeShop$Heater$Provider(
      coffeeModule,
    );
    _coffeeShop$brewer$Provider = _CoffeeShop$Brewer$Provider(
      coffeeShop$heater$Provider,
      coffeeModule,
    );
  }

  late final _CoffeeShop$Brewer$Provider _coffeeShop$brewer$Provider;

  @override
  _i1.Brewer get brewer => _coffeeShop$brewer$Provider.get();
}

class TeaShop$Component implements _i1.TeaShop {
  factory TeaShop$Component.create({_i1.TeaModule? teaModule}) =>
      TeaShop$Component._(teaModule ?? _i1.TeaModule());

  TeaShop$Component._(_i1.TeaModule teaModule) {
    final teaShop$kettle$Provider = _TeaShop$Kettle$Provider(teaModule);
    _teaShop$steeper$Provider = _TeaShop$Steeper$Provider(
      teaShop$kettle$Provider,
      teaModule,
    );
  }

  late final _TeaShop$Steeper$Provider _teaShop$steeper$Provider;

  @override
  _i1.Steeper get steeper => _teaShop$steeper$Provider.get();
}

class _CoffeeShop$Brewer$Provider implements _i2.Provider<_i1.Brewer> {
  const _CoffeeShop$Brewer$Provider(
    this._coffeeShop$heater$Provider,
    this._module,
  );

  final _CoffeeShop$Heater$Provider _coffeeShop$heater$Provider;

  final _i1.CoffeeModule _module;

  @override
  _i1.Brewer get() => _module.provideBrewer(_coffeeShop$heater$Provider.get());
}

class _CoffeeShop$Heater$Provider implements _i2.Provider<_i1.Heater> {
  _CoffeeShop$Heater$Provider(this._module);

  final _i1.CoffeeModule _module;

  late final _i1.Heater _singleton = _create();

  _i1.Heater _create() => _module.provideHeater();

  @override
  _i1.Heater get() => _singleton;
}

class _TeaShop$Kettle$Provider implements _i2.Provider<_i1.Kettle> {
  const _TeaShop$Kettle$Provider(this._module);

  final _i1.TeaModule _module;

  @override
  _i1.Kettle get() => _module.provideKettle();
}

class _TeaShop$Steeper$Provider implements _i2.Provider<_i1.Steeper> {
  const _TeaShop$Steeper$Provider(this._teaShop$kettle$Provider, this._module);

  final _TeaShop$Kettle$Provider _teaShop$kettle$Provider;

  final _i1.TeaModule _module;

  @override
  _i1.Steeper get() => _module.provideSteeper(_teaShop$kettle$Provider.get());
}
