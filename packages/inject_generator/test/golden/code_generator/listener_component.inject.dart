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

import 'listener_component.dart' as _i1;

class CoffeeComponent$Component implements _i1.CoffeeComponent {
  factory CoffeeComponent$Component.create({_i1.CoffeeModule? coffeeModule}) =>
      CoffeeComponent$Component._(coffeeModule ?? _i1.CoffeeModule());

  CoffeeComponent$Component._(_i1.CoffeeModule coffeeModule) {
    final provisionListenerOfObject$Provider =
        _ProvisionListenerOfObject$Provider(coffeeModule);
    _provisionListenerOfHeater$Provider = _ProvisionListenerOfHeater$Provider(
      coffeeModule,
    );
    final provisionListenerOfDynamicRawListener$Provider =
        _ProvisionListenerOfDynamicRawListener$Provider(coffeeModule);
    final provisionListenerOfDynamicDynamicListener$Provider =
        _ProvisionListenerOfDynamicDynamicListener$Provider(coffeeModule);
    _heater$Provider = _Heater$Provider(
      provisionListenerOfObject$Provider,
      _provisionListenerOfHeater$Provider,
      provisionListenerOfDynamicRawListener$Provider,
      provisionListenerOfDynamicDynamicListener$Provider,
      coffeeModule,
    );
    _pump$Provider = _Pump$Provider(
      provisionListenerOfObject$Provider,
      provisionListenerOfDynamicRawListener$Provider,
      provisionListenerOfDynamicDynamicListener$Provider,
      coffeeModule,
    );
    _solarPower$Provider = _SolarPower$Provider(
      provisionListenerOfObject$Provider,
      provisionListenerOfDynamicRawListener$Provider,
      provisionListenerOfDynamicDynamicListener$Provider,
      coffeeModule,
    );
  }

  late final _ProvisionListenerOfHeater$Provider
  _provisionListenerOfHeater$Provider;

  late final _Heater$Provider _heater$Provider;

  late final _Pump$Provider _pump$Provider;

  late final _SolarPower$Provider _solarPower$Provider;

  @override
  _i2.ProvisionListener<_i1.Heater> get heaterListener =>
      _provisionListenerOfHeater$Provider.get();

  @override
  _i1.Heater get heater => _heater$Provider.get();

  @override
  _i1.Pump get pump => _pump$Provider.get();

  @override
  _i3.Future<_i1.SolarPower> get solarPower => _solarPower$Provider.get();
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider(
    this._provisionListenerOfObject$Provider,
    this._provisionListenerOfHeater$Provider,
    this._provisionListenerOfDynamicRawListener$Provider,
    this._provisionListenerOfDynamicDynamicListener$Provider,
    this._module,
  );

  final _ProvisionListenerOfObject$Provider _provisionListenerOfObject$Provider;

  final _ProvisionListenerOfHeater$Provider _provisionListenerOfHeater$Provider;

  final _ProvisionListenerOfDynamicRawListener$Provider
  _provisionListenerOfDynamicRawListener$Provider;

  final _ProvisionListenerOfDynamicDynamicListener$Provider
  _provisionListenerOfDynamicDynamicListener$Provider;

  final _i1.CoffeeModule _module;

  @override
  _i1.Heater get() {
    final instance = _module.provideHeater();
    _provisionListenerOfObject$Provider.get().onProvision(instance);
    _provisionListenerOfHeater$Provider.get().onProvision(instance);
    _provisionListenerOfDynamicRawListener$Provider.get().onProvision(instance);
    _provisionListenerOfDynamicDynamicListener$Provider.get().onProvision(
      instance,
    );
    return instance;
  }
}

class _ProvisionListenerOfDynamicDynamicListener$Provider
    implements _i2.Provider<_i2.ProvisionListener<dynamic>> {
  _ProvisionListenerOfDynamicDynamicListener$Provider(this._module);

  final _i1.CoffeeModule _module;

  late final _i2.ProvisionListener<dynamic> _singleton = _create();

  _i2.ProvisionListener<dynamic> _create() => _module.provideDynamicListener();

  @override
  _i2.ProvisionListener<dynamic> get() => _singleton;
}

class _ProvisionListenerOfDynamicRawListener$Provider
    implements _i2.Provider<_i2.ProvisionListener<dynamic>> {
  _ProvisionListenerOfDynamicRawListener$Provider(this._module);

  final _i1.CoffeeModule _module;

  late final _i2.ProvisionListener<dynamic> _singleton = _create();

  _i2.ProvisionListener<dynamic> _create() => _module.provideRawListener();

  @override
  _i2.ProvisionListener<dynamic> get() => _singleton;
}

class _ProvisionListenerOfHeater$Provider
    implements _i2.Provider<_i2.ProvisionListener<_i1.Heater>> {
  _ProvisionListenerOfHeater$Provider(this._module);

  final _i1.CoffeeModule _module;

  late final _i2.ProvisionListener<_i1.Heater> _singleton = _create();

  _i2.ProvisionListener<_i1.Heater> _create() =>
      _module.provideHeaterListener();

  @override
  _i2.ProvisionListener<_i1.Heater> get() => _singleton;
}

class _ProvisionListenerOfObject$Provider
    implements _i2.Provider<_i2.ProvisionListener<Object>> {
  _ProvisionListenerOfObject$Provider(this._module);

  final _i1.CoffeeModule _module;

  late final _i2.ProvisionListener<Object> _singleton = _create();

  _i2.ProvisionListener<Object> _create() => _module.provideLoggingListener();

  @override
  _i2.ProvisionListener<Object> get() => _singleton;
}

class _Pump$Provider implements _i2.Provider<_i1.Pump> {
  _Pump$Provider(
    this._provisionListenerOfObject$Provider,
    this._provisionListenerOfDynamicRawListener$Provider,
    this._provisionListenerOfDynamicDynamicListener$Provider,
    this._module,
  );

  final _ProvisionListenerOfObject$Provider _provisionListenerOfObject$Provider;

  final _ProvisionListenerOfDynamicRawListener$Provider
  _provisionListenerOfDynamicRawListener$Provider;

  final _ProvisionListenerOfDynamicDynamicListener$Provider
  _provisionListenerOfDynamicDynamicListener$Provider;

  final _i1.CoffeeModule _module;

  late final _i1.Pump _singleton = _create();

  _i1.Pump _create() {
    final instance = _module.providePump();
    _provisionListenerOfObject$Provider.get().onProvision(instance);
    _provisionListenerOfDynamicRawListener$Provider.get().onProvision(instance);
    _provisionListenerOfDynamicDynamicListener$Provider.get().onProvision(
      instance,
    );
    return instance;
  }

  @override
  _i1.Pump get() => _singleton;
}

class _SolarPower$Provider implements _i2.Provider<_i3.Future<_i1.SolarPower>> {
  const _SolarPower$Provider(
    this._provisionListenerOfObject$Provider,
    this._provisionListenerOfDynamicRawListener$Provider,
    this._provisionListenerOfDynamicDynamicListener$Provider,
    this._module,
  );

  final _ProvisionListenerOfObject$Provider _provisionListenerOfObject$Provider;

  final _ProvisionListenerOfDynamicRawListener$Provider
  _provisionListenerOfDynamicRawListener$Provider;

  final _ProvisionListenerOfDynamicDynamicListener$Provider
  _provisionListenerOfDynamicDynamicListener$Provider;

  final _i1.CoffeeModule _module;

  @override
  _i3.Future<_i1.SolarPower> get() async {
    final instance = await _module.provideSolarPower();
    _provisionListenerOfObject$Provider.get().onProvision(instance);
    _provisionListenerOfDynamicRawListener$Provider.get().onProvision(instance);
    _provisionListenerOfDynamicDynamicListener$Provider.get().onProvision(
      instance,
    );
    return instance;
  }
}
