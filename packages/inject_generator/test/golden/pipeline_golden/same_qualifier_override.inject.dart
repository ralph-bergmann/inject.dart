// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'same_qualifier_override.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.AppModule? appModule,
    _i1.TestModule? testModule,
  }) => AppComponent$Component._(
    appModule ?? _i1.AppModule(),
    testModule ?? _i1.TestModule(),
  );

  AppComponent$Component._(_i1.AppModule appModule, _i1.TestModule testModule) {
    _stringProd$Provider = _StringProd$Provider(testModule);
  }

  late final _StringProd$Provider _stringProd$Provider;

  @override
  String get url => _stringProd$Provider.get();
}

class _StringProd$Provider implements _i2.Provider<String> {
  const _StringProd$Provider(this._module);

  final _i1.TestModule _module;

  @override
  String get() => _module.url();
}
