// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i2;

import 'package:inject_annotation/inject_annotation.dart' as _i3;

import 'subcomponent_factory_async_value_param.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.NetworkModule? networkModule}) =>
      AppComponent$Component._(networkModule ?? _i1.NetworkModule());

  AppComponent$Component._(_i1.NetworkModule networkModule) {
    _apiSubcomponentFactory$Provider = _ApiSubcomponentFactory$Provider(this);
  }

  late final _ApiSubcomponentFactory$Provider _apiSubcomponentFactory$Provider;

  @override
  _i1.ApiSubcomponentFactory get apiFactory =>
      _apiSubcomponentFactory$Provider.get();
}

class ApiSubcomponent$Subcomponent implements _i1.ApiSubcomponent {
  factory ApiSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    _i1.AsyncApiModule? asyncApiModule,
    required String userId,
  }) => ApiSubcomponent$Subcomponent._(
    parent,
    asyncApiModule ?? _i1.AsyncApiModule(),
    userId,
  );

  ApiSubcomponent$Subcomponent._(
    this._parent,
    _i1.AsyncApiModule asyncApiModule,
    this.userId,
  ) {
    final apiSubcomponent$httpClient$Provider =
        _ApiSubcomponent$HttpClient$Provider(asyncApiModule);
    _apiSubcomponent$string$Provider = _ApiSubcomponent$String$Provider(userId);
    _apiSubcomponent$restApiService$Provider =
        _ApiSubcomponent$RestApiService$Provider(
          apiSubcomponent$httpClient$Provider,
          _apiSubcomponent$string$Provider,
        );
  }

  final AppComponent$Component _parent;

  final String userId;

  late final _ApiSubcomponent$String$Provider _apiSubcomponent$string$Provider;

  late final _ApiSubcomponent$RestApiService$Provider
  _apiSubcomponent$restApiService$Provider;

  @override
  _i2.Future<_i1.RestApiService> get apiService =>
      _apiSubcomponent$restApiService$Provider.get();
}

class _ApiSubcomponentFactory$Factory implements _i1.ApiSubcomponentFactory {
  const _ApiSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.ApiSubcomponent create(String userId) =>
      ApiSubcomponent$Subcomponent.create(_parent, userId: userId);
}

class _ApiSubcomponent$HttpClient$Provider
    implements _i3.Provider<_i2.Future<_i1.HttpClient>> {
  const _ApiSubcomponent$HttpClient$Provider(this._module);

  final _i1.AsyncApiModule _module;

  @override
  _i2.Future<_i1.HttpClient> get() => _module.provideClient();
}

class _ApiSubcomponent$RestApiService$Provider
    implements _i3.Provider<_i2.Future<_i1.RestApiService>> {
  const _ApiSubcomponent$RestApiService$Provider(
    this._apiSubcomponent$httpClient$Provider,
    this._apiSubcomponent$string$Provider,
  );

  final _ApiSubcomponent$HttpClient$Provider
  _apiSubcomponent$httpClient$Provider;

  final _ApiSubcomponent$String$Provider _apiSubcomponent$string$Provider;

  @override
  _i2.Future<_i1.RestApiService> get() async => _i1.RestApiService(
    await (_apiSubcomponent$httpClient$Provider.get()),
    _apiSubcomponent$string$Provider.get(),
  );
}

class _ApiSubcomponent$String$Provider implements _i3.Provider<String> {
  const _ApiSubcomponent$String$Provider(this._value);

  final String _value;

  @override
  String get() => _value;
}

class _ApiSubcomponentFactory$Provider
    implements _i3.Provider<_i1.ApiSubcomponentFactory> {
  _ApiSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.ApiSubcomponentFactory _factory =
      _ApiSubcomponentFactory$Factory(_parent);

  @override
  _i1.ApiSubcomponentFactory get() => _factory;
}
