// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'inject_constructor_component.dart' as _i1;

class MyComponent$Component implements _i1.MyComponent {
  factory MyComponent$Component.create({_i1.MyModule? myModule}) =>
      MyComponent$Component._(myModule ?? _i1.MyModule());

  MyComponent$Component._(_i1.MyModule myModule) {
    final heater$Provider = _Heater$Provider(myModule);
    _coffeeMaker$Provider = _CoffeeMaker$Provider(heater$Provider);
  }

  late final _CoffeeMaker$Provider _coffeeMaker$Provider;

  @override
  _i1.CoffeeMaker get coffeeMaker => _coffeeMaker$Provider.get();
}

class _CoffeeMaker$Provider implements _i2.Provider<_i1.CoffeeMaker> {
  const _CoffeeMaker$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.CoffeeMaker get() => _i1.CoffeeMaker(_heater$Provider.get());
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider(this._module);

  final _i1.MyModule _module;

  @override
  _i1.Heater get() => _module.provideHeater();
}
