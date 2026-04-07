// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'qualifier_no_override.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.AppModule? appModule,
    _i1.TestModule? testModule,
  }) => AppComponent$Component._(
    appModule ?? _i1.AppModule(),
    testModule ?? _i1.TestModule(),
  );

  AppComponent$Component._(_i1.AppModule appModule, _i1.TestModule testModule) {
    _stringProd$Provider = _StringProd$Provider(appModule);
    _stringTest$Provider = _StringTest$Provider(testModule);
  }

  late final _StringProd$Provider _stringProd$Provider;

  late final _StringTest$Provider _stringTest$Provider;

  @override
  String get prodUrl => _stringProd$Provider.get();

  @override
  String get testUrl => _stringTest$Provider.get();
}

class _StringProd$Provider implements _i2.Provider<String> {
  const _StringProd$Provider(this._module);

  final _i1.AppModule _module;

  @override
  String get() => _module.url();
}

class _StringTest$Provider implements _i2.Provider<String> {
  const _StringTest$Provider(this._module);

  final _i1.TestModule _module;

  @override
  String get() => _module.url();
}
