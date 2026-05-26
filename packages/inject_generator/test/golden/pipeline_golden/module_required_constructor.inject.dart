// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'module_required_constructor.dart' as _i1;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({required _i1.DbModule dbModule}) =>
      MainComponent$Component._(dbModule);

  MainComponent$Component._(_i1.DbModule dbModule) {
    _foo$Provider = _Foo$Provider(dbModule);
  }

  late final _Foo$Provider _foo$Provider;

  @override
  _i1.Foo get foo => _foo$Provider.get();
}

class _Foo$Provider implements _i2.Provider<_i1.Foo> {
  const _Foo$Provider(this._module);

  final _i1.DbModule _module;

  @override
  _i1.Foo get() => _module.provideDatabase();
}
