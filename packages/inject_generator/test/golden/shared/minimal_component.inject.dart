// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'minimal_component.dart' as _i1;

class MyComponent$Component implements _i1.MyComponent {
  factory MyComponent$Component.create() => MyComponent$Component._();

  MyComponent$Component._() {
    _coffeeMaker$Provider = _CoffeeMaker$Provider();
  }

  late final _CoffeeMaker$Provider _coffeeMaker$Provider;

  @override
  _i1.CoffeeMaker get coffeeMaker => _coffeeMaker$Provider.get();
}

class _CoffeeMaker$Provider implements _i2.Provider<_i1.CoffeeMaker> {
  const _CoffeeMaker$Provider();

  @override
  _i1.CoffeeMaker get() => _i1.CoffeeMaker();
}
