// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'multi_module_component.dart' as _i1;

class MyComponent$Component implements _i1.MyComponent {
  factory MyComponent$Component.create({
    _i1.HeaterModule? heaterModule,
    _i1.PumpModule? pumpModule,
  }) => MyComponent$Component._(
    heaterModule ?? _i1.HeaterModule(),
    pumpModule ?? _i1.PumpModule(),
  );

  MyComponent$Component._(
    _i1.HeaterModule heaterModule,
    _i1.PumpModule pumpModule,
  ) {
    _heater$Provider = _Heater$Provider(heaterModule);
    _pump$Provider = _Pump$Provider(pumpModule);
  }

  late final _Heater$Provider _heater$Provider;

  late final _Pump$Provider _pump$Provider;

  @override
  _i1.Heater get heater => _heater$Provider.get();

  @override
  _i1.Pump get pump => _pump$Provider.get();
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider(this._module);

  final _i1.HeaterModule _module;

  @override
  _i1.Heater get() => _module.provideHeater();
}

class _Pump$Provider implements _i2.Provider<_i1.Pump> {
  const _Pump$Provider(this._module);

  final _i1.PumpModule _module;

  @override
  _i1.Pump get() => _module.providePump();
}
