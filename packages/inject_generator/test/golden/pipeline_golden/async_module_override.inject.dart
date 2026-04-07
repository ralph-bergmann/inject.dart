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

import 'async_module_override.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.AppModule? appModule,
    _i1.TestModule? testModule,
  }) => AppComponent$Component._(
    appModule ?? _i1.AppModule(),
    testModule ?? _i1.TestModule(),
  );

  AppComponent$Component._(_i1.AppModule appModule, _i1.TestModule testModule) {
    _database$Provider = _Database$Provider(testModule);
  }

  late final _Database$Provider _database$Provider;

  @override
  _i2.Future<_i1.Database> get db => _database$Provider.get();
}

class _Database$Provider implements _i3.Provider<_i2.Future<_i1.Database>> {
  _Database$Provider(this._module);

  final _i1.TestModule _module;

  _i2.Future<_i1.Database>? _singletonFuture;

  _i2.Future<_i1.Database> _create() => _module.provideDb();

  @override
  _i2.Future<_i1.Database> get() => _singletonFuture ??= _create();
}
