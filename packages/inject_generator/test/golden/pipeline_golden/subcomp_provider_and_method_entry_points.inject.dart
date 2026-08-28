// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'subcomp_provider_and_method_entry_points.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _brewSubcomponentFactory$Provider = _BrewSubcomponentFactory$Provider(this);
  }

  late final _BrewSubcomponentFactory$Provider
  _brewSubcomponentFactory$Provider;

  @override
  _i1.BrewSubcomponentFactory get brewFactory =>
      _brewSubcomponentFactory$Provider.get();
}

class BrewSubcomponent$Subcomponent implements _i1.BrewSubcomponent {
  factory BrewSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    _i1.BrewModule? brewModule,
  }) => BrewSubcomponent$Subcomponent._(parent, brewModule ?? _i1.BrewModule());

  BrewSubcomponent$Subcomponent._(this._parent, _i1.BrewModule brewModule) {
    _brewSubcomponent$coffeeMaker$Provider =
        _BrewSubcomponent$CoffeeMaker$Provider(brewModule);
    _brewSubcomponent$kettle$Provider = _BrewSubcomponent$Kettle$Provider(
      brewModule,
    );
  }

  final AppComponent$Component _parent;

  late final _BrewSubcomponent$CoffeeMaker$Provider
  _brewSubcomponent$coffeeMaker$Provider;

  late final _BrewSubcomponent$Kettle$Provider
  _brewSubcomponent$kettle$Provider;

  @override
  _i2.Provider<_i1.CoffeeMaker> get coffeeMaker =>
      _brewSubcomponent$coffeeMaker$Provider;

  @override
  _i1.Kettle getKettle() => _brewSubcomponent$kettle$Provider.get();
}

class _BrewSubcomponentFactory$Factory implements _i1.BrewSubcomponentFactory {
  const _BrewSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.BrewSubcomponent create({_i1.BrewModule? brewModule}) =>
      BrewSubcomponent$Subcomponent.create(_parent, brewModule: brewModule);
}

class _BrewSubcomponent$CoffeeMaker$Provider
    implements _i2.Provider<_i1.CoffeeMaker> {
  const _BrewSubcomponent$CoffeeMaker$Provider(this._module);

  final _i1.BrewModule _module;

  @override
  _i1.CoffeeMaker get() => _module.provideCoffeeMaker();
}

class _BrewSubcomponent$Kettle$Provider implements _i2.Provider<_i1.Kettle> {
  const _BrewSubcomponent$Kettle$Provider(this._module);

  final _i1.BrewModule _module;

  @override
  _i1.Kettle get() => _module.provideKettle();
}

class _BrewSubcomponentFactory$Provider
    implements _i2.Provider<_i1.BrewSubcomponentFactory> {
  _BrewSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.BrewSubcomponentFactory _factory =
      _BrewSubcomponentFactory$Factory(_parent);

  @override
  _i1.BrewSubcomponentFactory get() => _factory;
}
