// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'override_keeps_unique_binding.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.AppModule? appModule,
    _i1.TestModule? testModule,
  }) => AppComponent$Component._(
    appModule ?? _i1.AppModule(),
    testModule ?? _i1.TestModule(),
  );

  AppComponent$Component._(_i1.AppModule appModule, _i1.TestModule testModule) {
    _counter$Provider = _Counter$Provider(appModule);
    _string$Provider = _String$Provider(testModule);
  }

  late final _Counter$Provider _counter$Provider;

  late final _String$Provider _string$Provider;

  @override
  _i1.Counter get counter => _counter$Provider.get();

  @override
  String get message => _string$Provider.get();
}

class _Counter$Provider implements _i2.Provider<_i1.Counter> {
  const _Counter$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Counter get() => _module.counter();
}

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._module);

  final _i1.TestModule _module;

  @override
  String get() => _module.message();
}
