// ignore_for_file: implementation_imports
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:inject_annotation/inject_annotation.dart' as _i3;

import 'coffee_app.dart' as _i1;
import 'src/coffee_maker.dart' as _i6;
import 'src/drip_coffee_module.dart' as _i2;
import 'src/electric_heater.dart' as _i7;
import 'src/heater.dart' as _i8;
import 'src/pump.dart' as _i9;
import 'src/thermosiphon.dart' as _i5;

class Coffee$Component implements _i1.Coffee {
  factory Coffee$Component.create({_i2.DripCoffeeModule? dripCoffeeModule}) =>
      Coffee$Component._(dripCoffeeModule ?? _i2.DripCoffeeModule());

  Coffee$Component._(_i2.DripCoffeeModule dripCoffeeModule) {
    final powerOutlet$Provider = _PowerOutlet$Provider(dripCoffeeModule);
    final electricity$Provider = _Electricity$Provider(
      powerOutlet$Provider,
      dripCoffeeModule,
    );
    final heater$Provider = _Heater$Provider(
      electricity$Provider,
      dripCoffeeModule,
    );
    _thermosiphon$Provider = _Thermosiphon$Provider(heater$Provider);
    final pump$Provider = _Pump$Provider(
      heater$Provider,
      dripCoffeeModule,
    );
    final stringBrandName$Provider =
        _StringBrandName$Provider(dripCoffeeModule);
    final stringModelName$Provider =
        _StringModelName$Provider(dripCoffeeModule);
    _coffeeMaker$Provider = _CoffeeMaker$Provider(
      heater$Provider,
      pump$Provider,
      stringBrandName$Provider,
      stringModelName$Provider,
    );
  }

  late final _Thermosiphon$Provider _thermosiphon$Provider;

  late final _CoffeeMaker$Provider _coffeeMaker$Provider;

  @override
  _i3.Provider<_i4.Future<_i5.Thermosiphon>> get thermosiphon =>
      _thermosiphon$Provider;

  @override
  _i4.Future<_i6.CoffeeMaker> getCoffeeMaker() => _coffeeMaker$Provider.get();
}

class _PowerOutlet$Provider
    implements _i3.Provider<_i4.Future<_i7.PowerOutlet>> {
  const _PowerOutlet$Provider(this._module);

  final _i2.DripCoffeeModule _module;

  @override
  _i4.Future<_i7.PowerOutlet> get() async => await _module.providePowerOutlet();
}

class _Electricity$Provider
    implements _i3.Provider<_i4.Future<_i7.Electricity>> {
  _Electricity$Provider(
    this._powerOutlet$Provider,
    this._module,
  );

  final _PowerOutlet$Provider _powerOutlet$Provider;

  final _i2.DripCoffeeModule _module;

  _i7.Electricity? _singleton;

  @override
  _i4.Future<_i7.Electricity> get() async => _singleton ??=
      _module.provideElectricity(await _powerOutlet$Provider.get());
}

class _Heater$Provider implements _i3.Provider<_i4.Future<_i8.Heater>> {
  const _Heater$Provider(
    this._electricity$Provider,
    this._module,
  );

  final _Electricity$Provider _electricity$Provider;

  final _i2.DripCoffeeModule _module;

  @override
  _i4.Future<_i8.Heater> get() async =>
      await _module.provideHeater(await _electricity$Provider.get());
}

class _Thermosiphon$Provider
    implements _i3.Provider<_i4.Future<_i5.Thermosiphon>> {
  const _Thermosiphon$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i4.Future<_i5.Thermosiphon> get() async =>
      _i5.Thermosiphon(await _heater$Provider.get());
}

class _Pump$Provider implements _i3.Provider<_i4.Future<_i9.Pump>> {
  const _Pump$Provider(
    this._heater$Provider,
    this._module,
  );

  final _Heater$Provider _heater$Provider;

  final _i2.DripCoffeeModule _module;

  @override
  _i4.Future<_i9.Pump> get() async =>
      _module.providePump(await _heater$Provider.get());
}

class _StringBrandName$Provider implements _i3.Provider<String> {
  const _StringBrandName$Provider(this._module);

  final _i2.DripCoffeeModule _module;

  @override
  String get() => _module.provideBrand();
}

class _StringModelName$Provider implements _i3.Provider<String> {
  const _StringModelName$Provider(this._module);

  final _i2.DripCoffeeModule _module;

  @override
  String get() => _module.provideModel();
}

class _CoffeeMaker$Provider
    implements _i3.Provider<_i4.Future<_i6.CoffeeMaker>> {
  const _CoffeeMaker$Provider(
    this._heater$Provider,
    this._pump$Provider,
    this._stringBrandName$Provider,
    this._stringModelName$Provider,
  );

  final _Heater$Provider _heater$Provider;

  final _Pump$Provider _pump$Provider;

  final _StringBrandName$Provider _stringBrandName$Provider;

  final _StringModelName$Provider _stringModelName$Provider;

  @override
  _i4.Future<_i6.CoffeeMaker> get() async => _i6.CoffeeMaker(
        await _heater$Provider.get(),
        await _pump$Provider.get(),
        _stringBrandName$Provider.get(),
        _stringModelName$Provider.get(),
      );
}
