// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_multi_named_only.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    _coffeeMakerQuickFactory$Provider = _CoffeeMakerQuickFactory$Provider();
    _coffeeMakerSlowFactory$Provider = _CoffeeMakerSlowFactory$Provider();
  }

  late final _CoffeeMakerQuickFactory$Provider
  _coffeeMakerQuickFactory$Provider;

  late final _CoffeeMakerSlowFactory$Provider _coffeeMakerSlowFactory$Provider;

  @override
  _i1.CoffeeMakerQuickFactory get quickCoffeeMakerFactory =>
      _coffeeMakerQuickFactory$Provider.get();

  @override
  _i1.CoffeeMakerSlowFactory get slowCoffeeMakerFactory =>
      _coffeeMakerSlowFactory$Provider.get();
}

class _CoffeeMakerQuickFactory$Factory implements _i1.CoffeeMakerQuickFactory {
  const _CoffeeMakerQuickFactory$Factory();

  @override
  _i1.CoffeeMaker create(String name) => _i1.CoffeeMaker.quick(name);
}

class _CoffeeMakerQuickFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerQuickFactory> {
  _CoffeeMakerQuickFactory$Provider();

  late final _i1.CoffeeMakerQuickFactory _factory =
      _CoffeeMakerQuickFactory$Factory();

  @override
  _i1.CoffeeMakerQuickFactory get() => _factory;
}

class _CoffeeMakerSlowFactory$Factory implements _i1.CoffeeMakerSlowFactory {
  const _CoffeeMakerSlowFactory$Factory();

  @override
  _i1.CoffeeMaker create(int duration) => _i1.CoffeeMaker.slow(duration);
}

class _CoffeeMakerSlowFactory$Provider
    implements _i2.Provider<_i1.CoffeeMakerSlowFactory> {
  _CoffeeMakerSlowFactory$Provider();

  late final _i1.CoffeeMakerSlowFactory _factory =
      _CoffeeMakerSlowFactory$Factory();

  @override
  _i1.CoffeeMakerSlowFactory get() => _factory;
}
