// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'sorted_providers_component.dart' as _i1;

class MyComponent$Component implements _i1.MyComponent {
  factory MyComponent$Component.create({_i1.MyModule? myModule}) =>
      MyComponent$Component._(myModule ?? _i1.MyModule());

  MyComponent$Component._(_i1.MyModule myModule) {
    _apple$Provider = _Apple$Provider(myModule);
    _zebra$Provider = _Zebra$Provider(myModule);
  }

  late final _Apple$Provider _apple$Provider;

  late final _Zebra$Provider _zebra$Provider;

  @override
  _i1.Apple get apple => _apple$Provider.get();

  @override
  _i1.Zebra get zebra => _zebra$Provider.get();
}

class _Apple$Provider implements _i2.Provider<_i1.Apple> {
  const _Apple$Provider(this._module);

  final _i1.MyModule _module;

  @override
  _i1.Apple get() => _module.provideApple();
}

class _Zebra$Provider implements _i2.Provider<_i1.Zebra> {
  const _Zebra$Provider(this._module);

  final _i1.MyModule _module;

  @override
  _i1.Zebra get() => _module.provideZebra();
}
