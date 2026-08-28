// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'subcomp_installed_via_include.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.NetworkModule? networkModule,
    _i1.UmbrellaModule? umbrellaModule,
  }) => AppComponent$Component._(
    networkModule ?? _i1.NetworkModule(),
    umbrellaModule ?? _i1.UmbrellaModule(),
  );

  AppComponent$Component._(
    _i1.NetworkModule networkModule,
    _i1.UmbrellaModule umbrellaModule,
  ) {
    _database$Provider = _Database$Provider(networkModule);
    _httpSubcomponentFactory$Provider = _HttpSubcomponentFactory$Provider(this);
  }

  late final _Database$Provider _database$Provider;

  late final _HttpSubcomponentFactory$Provider
  _httpSubcomponentFactory$Provider;

  @override
  _i1.Database get db => _database$Provider.get();

  @override
  _i1.HttpSubcomponentFactory get httpFactory =>
      _httpSubcomponentFactory$Provider.get();
}

class HttpSubcomponent$Subcomponent implements _i1.HttpSubcomponent {
  factory HttpSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    _i1.HttpModule? httpModule,
  }) => HttpSubcomponent$Subcomponent._(parent, httpModule ?? _i1.HttpModule());

  HttpSubcomponent$Subcomponent._(this._parent, _i1.HttpModule httpModule) {
    _httpSubcomponent$apiService$Provider =
        _HttpSubcomponent$ApiService$Provider(
          _parent._database$Provider,
          httpModule,
        );
  }

  final AppComponent$Component _parent;

  late final _HttpSubcomponent$ApiService$Provider
  _httpSubcomponent$apiService$Provider;

  @override
  _i1.ApiService get apiService => _httpSubcomponent$apiService$Provider.get();
}

class _HttpSubcomponentFactory$Factory implements _i1.HttpSubcomponentFactory {
  const _HttpSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.HttpSubcomponent create({_i1.HttpModule? httpModule}) =>
      HttpSubcomponent$Subcomponent.create(_parent, httpModule: httpModule);
}

class _Database$Provider implements _i2.Provider<_i1.Database> {
  _Database$Provider(this._module);

  final _i1.NetworkModule _module;

  late final _i1.Database _singleton = _create();

  _i1.Database _create() => _module.provideDatabase();

  @override
  _i1.Database get() => _singleton;
}

class _HttpSubcomponent$ApiService$Provider
    implements _i2.Provider<_i1.ApiService> {
  const _HttpSubcomponent$ApiService$Provider(
    this._database$Provider,
    this._module,
  );

  final _Database$Provider _database$Provider;

  final _i1.HttpModule _module;

  @override
  _i1.ApiService get() => _module.provideApi(_database$Provider.get());
}

class _HttpSubcomponentFactory$Provider
    implements _i2.Provider<_i1.HttpSubcomponentFactory> {
  _HttpSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.HttpSubcomponentFactory _factory =
      _HttpSubcomponentFactory$Factory(_parent);

  @override
  _i1.HttpSubcomponentFactory get() => _factory;
}
