// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'provider_future_entry_point_component.dart' as _i1;

class MyComponent$Component implements _i1.MyComponent {
  factory MyComponent$Component.create({_i1.CoffeeModule? coffeeModule}) =>
      MyComponent$Component._(coffeeModule ?? _i1.CoffeeModule());

  MyComponent$Component._(_i1.CoffeeModule coffeeModule) {
    _coffeeMaker$Provider = _CoffeeMaker$Provider(coffeeModule);
  }

  late final _CoffeeMaker$Provider _coffeeMaker$Provider;

  @override
  _i2.Provider<_i3.Future<_i1.CoffeeMaker>> get coffeeMaker =>
      _coffeeMaker$Provider;
}

class _CoffeeMaker$Provider
    implements _i2.Provider<_i3.Future<_i1.CoffeeMaker>> {
  const _CoffeeMaker$Provider(this._module);

  final _i1.CoffeeModule _module;

  @override
  _i3.Future<_i1.CoffeeMaker> get() => _module.coffee();
}
