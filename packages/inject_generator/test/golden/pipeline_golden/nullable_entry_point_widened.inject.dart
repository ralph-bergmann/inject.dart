// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i2;

import 'package:inject_annotation/inject_annotation.dart' as _i3;

import 'nullable_entry_point_widened.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _clock$Provider = _Clock$Provider(appModule);
    _db$Provider = _Db$Provider(appModule);
    _log$Provider = _Log$Provider(appModule);
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
    _timer$Provider = _Timer$Provider();
  }

  late final _Clock$Provider _clock$Provider;

  late final _Db$Provider _db$Provider;

  late final _Log$Provider _log$Provider;

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

  late final _Timer$Provider _timer$Provider;

  @override
  _i1.Clock? get clock => _clock$Provider.get();

  @override
  _i2.Future<_i1.Db?> get db => _db$Provider.get();

  @override
  _i1.Log? get log => _log$Provider.get();

  @override
  _i1.Log get requiredLog => _log$Provider.get();

  @override
  _i3.Provider<_i1.Log?> get logProvider => _log$Provider;

  @override
  _i1.SessionSubcomponentFactory get sessionFactory =>
      _sessionSubcomponentFactory$Provider.get();

  @override
  _i1.Timer? get timer => _timer$Provider.get();
}

class SessionSubcomponent$Subcomponent implements _i1.SessionSubcomponent {
  factory SessionSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    _i1.SessionModule? sessionModule,
  }) => SessionSubcomponent$Subcomponent._(
    parent,
    sessionModule ?? _i1.SessionModule(),
  );

  SessionSubcomponent$Subcomponent._(
    this._parent,
    _i1.SessionModule sessionModule,
  ) {
    _sessionSubcomponent$token$Provider = _SessionSubcomponent$Token$Provider(
      sessionModule,
    );
  }

  final AppComponent$Component _parent;

  late final _SessionSubcomponent$Token$Provider
  _sessionSubcomponent$token$Provider;

  @override
  _i1.Token? get token => _sessionSubcomponent$token$Provider.get();

  @override
  _i1.Clock? get clock => _parent._clock$Provider.get();
}

class _SessionSubcomponentFactory$Factory
    implements _i1.SessionSubcomponentFactory {
  const _SessionSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.SessionSubcomponent create({_i1.SessionModule? sessionModule}) =>
      SessionSubcomponent$Subcomponent.create(
        _parent,
        sessionModule: sessionModule,
      );
}

class _Clock$Provider implements _i3.Provider<_i1.Clock> {
  const _Clock$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Clock get() => _module.provideClock();
}

class _Db$Provider implements _i3.Provider<_i2.Future<_i1.Db>> {
  const _Db$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.Db> get() => _module.provideDb();
}

class _Log$Provider implements _i3.Provider<_i1.Log> {
  const _Log$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Log get() => _module.provideLog();
}

class _SessionSubcomponent$Token$Provider implements _i3.Provider<_i1.Token> {
  const _SessionSubcomponent$Token$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i1.Token get() => _module.provideToken();
}

class _SessionSubcomponentFactory$Provider
    implements _i3.Provider<_i1.SessionSubcomponentFactory> {
  _SessionSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.SessionSubcomponentFactory _factory =
      _SessionSubcomponentFactory$Factory(_parent);

  @override
  _i1.SessionSubcomponentFactory get() => _factory;
}

class _Timer$Provider implements _i3.Provider<_i1.Timer> {
  const _Timer$Provider();

  @override
  _i1.Timer get() => _i1.Timer();
}
