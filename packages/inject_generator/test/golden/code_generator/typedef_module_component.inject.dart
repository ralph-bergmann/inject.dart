// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'typedef_module_component.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final onEvent$Provider = _OnEvent$Provider(appModule);
    final userData$Provider = _UserData$Provider(appModule);
    _eventLogger$Provider = _EventLogger$Provider(
      onEvent$Provider,
      userData$Provider,
    );
  }

  late final _EventLogger$Provider _eventLogger$Provider;

  @override
  _i1.EventLogger get eventLogger => _eventLogger$Provider.get();
}

class _EventLogger$Provider implements _i2.Provider<_i1.EventLogger> {
  const _EventLogger$Provider(this._onEvent$Provider, this._userData$Provider);

  final _OnEvent$Provider _onEvent$Provider;

  final _UserData$Provider _userData$Provider;

  @override
  _i1.EventLogger get() =>
      _i1.EventLogger(_onEvent$Provider.get(), _userData$Provider.get());
}

class _OnEvent$Provider implements _i2.Provider<_i1.OnEvent> {
  const _OnEvent$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.OnEvent get() => _module.provideOnEvent();
}

class _UserData$Provider implements _i2.Provider<_i1.UserData> {
  const _UserData$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.UserData get() => _module.provideUserData();
}
