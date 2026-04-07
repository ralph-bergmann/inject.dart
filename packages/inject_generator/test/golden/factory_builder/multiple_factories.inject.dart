// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'multiple_factories.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    _grinder$Provider = _Grinder$Provider();
    _espressoFactory$Provider = _EspressoFactory$Provider(_grinder$Provider);
    _heater$Provider = _Heater$Provider();
    _pourOverFactory$Provider = _PourOverFactory$Provider(_heater$Provider);
  }

  late final _Grinder$Provider _grinder$Provider;

  late final _EspressoFactory$Provider _espressoFactory$Provider;

  late final _Heater$Provider _heater$Provider;

  late final _PourOverFactory$Provider _pourOverFactory$Provider;

  @override
  _i1.Grinder get grinder => _grinder$Provider.get();

  @override
  _i1.EspressoFactory get espressoFactory => _espressoFactory$Provider.get();

  @override
  _i1.Heater get heater => _heater$Provider.get();

  @override
  _i1.PourOverFactory get pourOverFactory => _pourOverFactory$Provider.get();
}

class _EspressoFactory$Factory implements _i1.EspressoFactory {
  const _EspressoFactory$Factory(this._grinder$Provider);

  final _Grinder$Provider _grinder$Provider;

  @override
  _i1.Espresso create(String roast) =>
      _i1.Espresso(_grinder$Provider.get(), roast);
}

class _EspressoFactory$Provider implements _i2.Provider<_i1.EspressoFactory> {
  _EspressoFactory$Provider(this._grinder$Provider);

  final _Grinder$Provider _grinder$Provider;

  late final _i1.EspressoFactory _factory = _EspressoFactory$Factory(
    _grinder$Provider,
  );

  @override
  _i1.EspressoFactory get() => _factory;
}

class _Grinder$Provider implements _i2.Provider<_i1.Grinder> {
  const _Grinder$Provider();

  @override
  _i1.Grinder get() => _i1.Grinder();
}

class _Heater$Provider implements _i2.Provider<_i1.Heater> {
  const _Heater$Provider();

  @override
  _i1.Heater get() => _i1.Heater();
}

class _PourOverFactory$Factory implements _i1.PourOverFactory {
  const _PourOverFactory$Factory(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  @override
  _i1.PourOver create({required int grams, required String origin}) =>
      _i1.PourOver(_heater$Provider.get(), origin: origin, grams: grams);
}

class _PourOverFactory$Provider implements _i2.Provider<_i1.PourOverFactory> {
  _PourOverFactory$Provider(this._heater$Provider);

  final _Heater$Provider _heater$Provider;

  late final _i1.PourOverFactory _factory = _PourOverFactory$Factory(
    _heater$Provider,
  );

  @override
  _i1.PourOverFactory get() => _factory;
}
