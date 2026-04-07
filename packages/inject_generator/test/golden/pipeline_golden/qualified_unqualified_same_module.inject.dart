// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'qualified_unqualified_same_module.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _string$Provider = _String$Provider(appModule);
    _stringBranded$Provider = _StringBranded$Provider(appModule);
  }

  late final _String$Provider _string$Provider;

  late final _StringBranded$Provider _stringBranded$Provider;

  @override
  String get defaultValue => _string$Provider.get();

  @override
  String get brandedValue => _stringBranded$Provider.get();
}

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._module);

  final _i1.AppModule _module;

  @override
  String get() => _module.provideDefault();
}

class _StringBranded$Provider implements _i2.Provider<String> {
  const _StringBranded$Provider(this._module);

  final _i1.AppModule _module;

  @override
  String get() => _module.provideBranded();
}
