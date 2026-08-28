// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'umbrella_module_include.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.GreetingModule? greetingModule,
    _i1.UmbrellaModule? umbrellaModule,
  }) => AppComponent$Component._(
    greetingModule ?? _i1.GreetingModule(),
    umbrellaModule ?? _i1.UmbrellaModule(),
  );

  AppComponent$Component._(
    _i1.GreetingModule greetingModule,
    _i1.UmbrellaModule umbrellaModule,
  ) {
    _string$Provider = _String$Provider(greetingModule);
  }

  late final _String$Provider _string$Provider;

  @override
  String get greeting => _string$Provider.get();
}

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._module);

  final _i1.GreetingModule _module;

  @override
  String get() => _module.provideGreeting();
}
