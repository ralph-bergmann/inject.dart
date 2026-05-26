// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'valid_pair.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    _coffeeService$Provider = _CoffeeService$Provider();
    _myServiceFactory$Provider = _MyServiceFactory$Provider(
      _coffeeService$Provider,
    );
  }

  late final _CoffeeService$Provider _coffeeService$Provider;

  late final _MyServiceFactory$Provider _myServiceFactory$Provider;

  @override
  _i1.CoffeeService get coffeeService => _coffeeService$Provider.get();

  @override
  _i1.MyServiceFactory get myServiceFactory => _myServiceFactory$Provider.get();
}

class _CoffeeService$Provider implements _i2.Provider<_i1.CoffeeService> {
  const _CoffeeService$Provider();

  @override
  _i1.CoffeeService get() => _i1.CoffeeService();
}

class _MyServiceFactory$Factory implements _i1.MyServiceFactory {
  const _MyServiceFactory$Factory(this._coffeeService$Provider);

  final _CoffeeService$Provider _coffeeService$Provider;

  @override
  _i1.MyService create(String name) =>
      _i1.MyService(name, _coffeeService$Provider.get());
}

class _MyServiceFactory$Provider implements _i2.Provider<_i1.MyServiceFactory> {
  _MyServiceFactory$Provider(this._coffeeService$Provider);

  final _CoffeeService$Provider _coffeeService$Provider;

  late final _i1.MyServiceFactory _factory = _MyServiceFactory$Factory(
    _coffeeService$Provider,
  );

  @override
  _i1.MyServiceFactory get() => _factory;
}
