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

import 'async_dep_component.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final database$Provider = _Database$Provider(appModule);
    final futureOfApi$Provider = _FutureOfApi$Provider(appModule);
    _service$Provider = _Service$Provider(
      database$Provider,
      futureOfApi$Provider,
    );
  }

  late final _Service$Provider _service$Provider;

  @override
  _i2.Future<_i1.Service> get service => _service$Provider.get();
}

class _Database$Provider implements _i3.Provider<_i2.Future<_i1.Database>> {
  const _Database$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.Database> get() => _module.provideDatabase();
}

class _FutureOfApi$Provider implements _i3.Provider<_i2.Future<_i1.Api>> {
  const _FutureOfApi$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.Api> get() => _module.provideApi();
}

class _Service$Provider implements _i3.Provider<_i2.Future<_i1.Service>> {
  const _Service$Provider(this._database$Provider, this._futureOfApi$Provider);

  final _Database$Provider _database$Provider;

  final _FutureOfApi$Provider _futureOfApi$Provider;

  @override
  _i2.Future<_i1.Service> get() async => _i1.Service(
    await (_database$Provider.get()),
    _futureOfApi$Provider.get(),
  );
}
