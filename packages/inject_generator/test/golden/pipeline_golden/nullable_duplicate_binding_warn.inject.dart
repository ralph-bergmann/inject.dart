// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nullable_duplicate_binding_warn.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _config$Provider = _Config$Provider(appModule);
    _configNullable$Provider = _ConfigNullable$Provider(appModule);
  }

  late final _Config$Provider _config$Provider;

  late final _ConfigNullable$Provider _configNullable$Provider;

  @override
  _i1.Config get config => _config$Provider.get();

  @override
  _i1.Config? get optionalConfig => _configNullable$Provider.get();
}

class _Config$Provider implements _i2.Provider<_i1.Config> {
  const _Config$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Config get() => _module.provideConfig();
}

class _ConfigNullable$Provider implements _i2.Provider<_i1.Config?> {
  const _ConfigNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Config? get() => _module.provideOptionalConfig();
}
