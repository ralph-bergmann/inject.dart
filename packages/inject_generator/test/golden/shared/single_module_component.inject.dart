// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'single_module_component.dart' as _i1;

class MyComponent$Component implements _i1.MyComponent {
  factory MyComponent$Component.create({_i1.MyModule? myModule}) =>
      MyComponent$Component._(myModule ?? _i1.MyModule());

  MyComponent$Component._(_i1.MyModule myModule) {
    _string$Provider = _String$Provider(myModule);
  }

  late final _String$Provider _string$Provider;

  @override
  String get name => _string$Provider.get();
}

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._module);

  final _i1.MyModule _module;

  @override
  String get() => _module.provideName();
}
