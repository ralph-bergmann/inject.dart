// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'umbrella_module_diamond_include.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.SharedModule? sharedModule,
    _i1.LeftModule? leftModule,
    _i1.RightModule? rightModule,
    _i1.TopModule? topModule,
  }) => AppComponent$Component._(
    sharedModule ?? _i1.SharedModule(),
    leftModule ?? _i1.LeftModule(),
    rightModule ?? _i1.RightModule(),
    topModule ?? _i1.TopModule(),
  );

  AppComponent$Component._(
    _i1.SharedModule sharedModule,
    _i1.LeftModule leftModule,
    _i1.RightModule rightModule,
    _i1.TopModule topModule,
  ) {
    _int$Provider = _Int$Provider(sharedModule);
  }

  late final _Int$Provider _int$Provider;

  @override
  int get value => _int$Provider.get();
}

class _Int$Provider implements _i2.Provider<int> {
  const _Int$Provider(this._module);

  final _i1.SharedModule _module;

  @override
  int get() => _module.provideValue();
}
