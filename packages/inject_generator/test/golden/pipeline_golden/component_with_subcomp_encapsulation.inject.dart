// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'component_with_subcomp_encapsulation.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.NetworkModule? networkModule}) =>
      AppComponent$Component._(networkModule ?? _i1.NetworkModule());

  AppComponent$Component._(_i1.NetworkModule networkModule) {
    _database$Provider = _Database$Provider();
    final httpSubcomponentFactory$Provider = _HttpSubcomponentFactory$Provider(
      this,
    );
    _restApiService$Provider = _RestApiService$Provider(
      httpSubcomponentFactory$Provider,
      networkModule,
    );
  }

  late final _Database$Provider _database$Provider;

  late final _RestApiService$Provider _restApiService$Provider;

  @override
  _i1.Database get db => _database$Provider.get();

  @override
  _i1.RestApiService get api => _restApiService$Provider.get();
}

class HttpSubcomponent$Subcomponent implements _i1.HttpSubcomponent {
  factory HttpSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    _i1.HttpModule? httpModule,
  }) => HttpSubcomponent$Subcomponent._(parent, httpModule ?? _i1.HttpModule());

  HttpSubcomponent$Subcomponent._(this._parent, _i1.HttpModule httpModule) {
    final httpSubcomponent$httpClient$Provider =
        _HttpSubcomponent$HttpClient$Provider(httpModule);
    _httpSubcomponent$restApiServiceInternal$Provider =
        _HttpSubcomponent$RestApiServiceInternal$Provider(
          httpSubcomponent$httpClient$Provider,
          _parent._database$Provider,
          httpModule,
        );
  }

  final AppComponent$Component _parent;

  late final _HttpSubcomponent$RestApiServiceInternal$Provider
  _httpSubcomponent$restApiServiceInternal$Provider;

  @override
  _i1.RestApiService get apiService =>
      _httpSubcomponent$restApiServiceInternal$Provider.get();
}

class _HttpSubcomponentFactory$Factory implements _i1.HttpSubcomponentFactory {
  const _HttpSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.HttpSubcomponent create({_i1.HttpModule? httpModule}) =>
      HttpSubcomponent$Subcomponent.create(_parent, httpModule: httpModule);
}

class _Database$Provider implements _i2.Provider<_i1.Database> {
  _Database$Provider();

  late final _i1.Database _singleton = _create();

  _i1.Database _create() => _i1.Database();

  @override
  _i1.Database get() => _singleton;
}

class _HttpSubcomponent$HttpClient$Provider
    implements _i2.Provider<_i1.HttpClient> {
  _HttpSubcomponent$HttpClient$Provider(this._module);

  final _i1.HttpModule _module;

  late final _i1.HttpClient _singleton = _create();

  _i1.HttpClient _create() => _module.provideClient();

  @override
  _i1.HttpClient get() => _singleton;
}

class _HttpSubcomponent$RestApiServiceInternal$Provider
    implements _i2.Provider<_i1.RestApiService> {
  const _HttpSubcomponent$RestApiServiceInternal$Provider(
    this._httpSubcomponent$httpClient$Provider,
    this._database$Provider,
    this._module,
  );

  final _HttpSubcomponent$HttpClient$Provider
  _httpSubcomponent$httpClient$Provider;

  final _Database$Provider _database$Provider;

  final _i1.HttpModule _module;

  @override
  _i1.RestApiService get() => _module.provideApi(
    _httpSubcomponent$httpClient$Provider.get(),
    _database$Provider.get(),
  );
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

class _RestApiService$Provider implements _i2.Provider<_i1.RestApiService> {
  _RestApiService$Provider(
    this._httpSubcomponentFactory$Provider,
    this._module,
  );

  final _HttpSubcomponentFactory$Provider _httpSubcomponentFactory$Provider;

  final _i1.NetworkModule _module;

  late final _i1.RestApiService _singleton = _create();

  _i1.RestApiService _create() =>
      _module.provideApi(_httpSubcomponentFactory$Provider.get());

  @override
  _i1.RestApiService get() => _singleton;
}
