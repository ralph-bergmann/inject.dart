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

import 'nullable_module_provider_param.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final bar$Provider = _Bar$Provider(appModule);
    final foo$Provider = _Foo$Provider(appModule);
    _string$Provider = _String$Provider(foo$Provider, appModule);
    _double$Provider = _Double$Provider(bar$Provider, appModule);
    _int$Provider = _Int$Provider(foo$Provider, appModule);
  }

  late final _String$Provider _string$Provider;

  late final _Double$Provider _double$Provider;

  late final _Int$Provider _int$Provider;

  @override
  String get name => _string$Provider.get();

  @override
  _i2.Future<double> get ratio => _double$Provider.get();

  @override
  int get count => _int$Provider.get();
}

class _Bar$Provider implements _i3.Provider<_i2.Future<_i1.Bar>> {
  const _Bar$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.Bar> get() => _module.provideBar();
}

class _Double$Provider implements _i3.Provider<_i2.Future<double>> {
  const _Double$Provider(this._bar$Provider, this._module);

  final _Bar$Provider _bar$Provider;

  final _i1.AppModule _module;

  @override
  _i2.Future<double> get() async => _module.ratio(await _bar$Provider.get());
}

class _Foo$Provider implements _i3.Provider<_i1.Foo> {
  const _Foo$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Foo get() => _module.provideFoo();
}

class _Int$Provider implements _i3.Provider<int> {
  const _Int$Provider(this._foo$Provider, this._module);

  final _Foo$Provider _foo$Provider;

  final _i1.AppModule _module;

  @override
  int get() => _module.count(_foo$Provider.get(), _foo$Provider.get());
}

class _String$Provider implements _i3.Provider<String> {
  const _String$Provider(this._foo$Provider, this._module);

  final _Foo$Provider _foo$Provider;

  final _i1.AppModule _module;

  @override
  String get() => _module.name(_foo$Provider.get());
}
