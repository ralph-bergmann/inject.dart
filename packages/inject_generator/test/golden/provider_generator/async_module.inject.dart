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

import 'async_module.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.DatabaseModule? databaseModule}) =>
      AppComponent$Component._(databaseModule ?? _i1.DatabaseModule());

  AppComponent$Component._(_i1.DatabaseModule databaseModule) {
    _closableListener$Provider = _ClosableListener$Provider(databaseModule);
    final httpClient$Provider = _HttpClient$Provider(
      _closableListener$Provider,
    );
    final databaseConnection$Provider = _DatabaseConnection$Provider(
      httpClient$Provider,
      _closableListener$Provider,
      databaseModule,
    );
    _databaseService$Provider = _DatabaseService$Provider(
      databaseConnection$Provider,
      databaseModule,
    );
  }

  late final _ClosableListener$Provider _closableListener$Provider;

  late final _DatabaseService$Provider _databaseService$Provider;

  @override
  _i1.ClosableListener get closableListener => _closableListener$Provider.get();

  @override
  _i2.Future<_i1.DatabaseService> get databaseService =>
      _databaseService$Provider.get();
}

class _ClosableListener$Provider implements _i3.Provider<_i1.ClosableListener> {
  _ClosableListener$Provider(this._module);

  final _i1.DatabaseModule _module;

  late final _i1.ClosableListener _singleton = _create();

  _i1.ClosableListener _create() => _module.provideClosableListener();

  @override
  _i1.ClosableListener get() => _singleton;
}

class _DatabaseConnection$Provider
    implements _i3.Provider<_i2.Future<_i1.DatabaseConnection>> {
  _DatabaseConnection$Provider(
    this._httpClient$Provider,
    this._closableListener$Provider,
    this._module,
  );

  final _HttpClient$Provider _httpClient$Provider;

  final _ClosableListener$Provider _closableListener$Provider;

  final _i1.DatabaseModule _module;

  _i2.Future<_i1.DatabaseConnection>? _singletonFuture;

  _i2.Future<_i1.DatabaseConnection> _create() async {
    final instance = await _module.provideDatabaseConnection(
      _httpClient$Provider.get(),
    );
    _closableListener$Provider.get().onProvision(instance);
    return instance;
  }

  @override
  _i2.Future<_i1.DatabaseConnection> get() => _singletonFuture ??= _create();
}

class _DatabaseService$Provider
    implements _i3.Provider<_i2.Future<_i1.DatabaseService>> {
  const _DatabaseService$Provider(
    this._databaseConnection$Provider,
    this._module,
  );

  final _DatabaseConnection$Provider _databaseConnection$Provider;

  final _i1.DatabaseModule _module;

  @override
  _i2.Future<_i1.DatabaseService> get() async =>
      _module.provideDatabaseService(await _databaseConnection$Provider.get());
}

class _HttpClient$Provider implements _i3.Provider<_i1.HttpClient> {
  _HttpClient$Provider(this._closableListener$Provider);

  final _ClosableListener$Provider _closableListener$Provider;

  late final _i1.HttpClient _singleton = _create();

  _i1.HttpClient _create() {
    final instance = _i1.HttpClient();
    _closableListener$Provider.get().onProvision(instance);
    return instance;
  }

  @override
  _i1.HttpClient get() => _singleton;
}
