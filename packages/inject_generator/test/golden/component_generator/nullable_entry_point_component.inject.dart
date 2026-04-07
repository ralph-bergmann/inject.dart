// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nullable_entry_point_component.dart' as _i1;

class MyComponent$Component implements _i1.MyComponent {
  factory MyComponent$Component.create({_i1.CoffeeModule? coffeeModule}) =>
      MyComponent$Component._(coffeeModule ?? _i1.CoffeeModule());

  MyComponent$Component._(_i1.CoffeeModule coffeeModule) {
    _string$Provider = _String$Provider(coffeeModule);
    _stringNullable$Provider = _StringNullable$Provider(coffeeModule);
  }

  late final _String$Provider _string$Provider;

  late final _StringNullable$Provider _stringNullable$Provider;

  @override
  String get name => _string$Provider.get();

  @override
  String? get nickname => _stringNullable$Provider.get();
}

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._module);

  final _i1.CoffeeModule _module;

  @override
  String get() => _module.provideName();
}

class _StringNullable$Provider implements _i2.Provider<String?> {
  const _StringNullable$Provider(this._module);

  final _i1.CoffeeModule _module;

  @override
  String? get() => _module.provideNickname();
}
