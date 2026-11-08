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

import 'nullable_parent_reader_beside_child_exact.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final asyncFoo$Provider = _AsyncFoo$Provider(appModule);
    _asyncFooReader$Provider = _AsyncFooReader$Provider(asyncFoo$Provider);
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
    final syncFoo$Provider = _SyncFoo$Provider(appModule);
    _syncFooReader$Provider = _SyncFooReader$Provider(syncFoo$Provider);
  }

  late final _AsyncFooReader$Provider _asyncFooReader$Provider;

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

  late final _SyncFooReader$Provider _syncFooReader$Provider;

  @override
  _i2.Future<_i1.AsyncFooReader> get asyncFooReader =>
      _asyncFooReader$Provider.get();

  @override
  _i1.SessionSubcomponentFactory get sessionFactory =>
      _sessionSubcomponentFactory$Provider.get();

  @override
  _i1.SyncFooReader get syncFooReader => _syncFooReader$Provider.get();
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
    _sessionSubcomponent$asyncFooNullable$Provider =
        _SessionSubcomponent$AsyncFooNullable$Provider(sessionModule);
    _sessionSubcomponent$syncFooNullable$Provider =
        _SessionSubcomponent$SyncFooNullable$Provider(sessionModule);
  }

  final AppComponent$Component _parent;

  late final _SessionSubcomponent$AsyncFooNullable$Provider
  _sessionSubcomponent$asyncFooNullable$Provider;

  late final _SessionSubcomponent$SyncFooNullable$Provider
  _sessionSubcomponent$syncFooNullable$Provider;

  @override
  _i1.AsyncFoo? get asyncFoo =>
      _sessionSubcomponent$asyncFooNullable$Provider.get();

  @override
  _i2.Future<_i1.SyncFoo?> get syncFoo =>
      _sessionSubcomponent$syncFooNullable$Provider.get();

  @override
  _i2.Future<_i1.AsyncFooReader> get asyncFooReader =>
      _parent._asyncFooReader$Provider.get();

  @override
  _i1.SyncFooReader get syncFooReader => _parent._syncFooReader$Provider.get();
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

class _AsyncFoo$Provider implements _i3.Provider<_i2.Future<_i1.AsyncFoo>> {
  const _AsyncFoo$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.AsyncFoo> get() => _module.provideAsyncFoo();
}

class _AsyncFooReader$Provider
    implements _i3.Provider<_i2.Future<_i1.AsyncFooReader>> {
  const _AsyncFooReader$Provider(this._asyncFoo$Provider);

  final _AsyncFoo$Provider _asyncFoo$Provider;

  @override
  _i2.Future<_i1.AsyncFooReader> get() async =>
      _i1.AsyncFooReader(await (_asyncFoo$Provider.get()));
}

class _SessionSubcomponent$AsyncFooNullable$Provider
    implements _i3.Provider<_i1.AsyncFoo?> {
  const _SessionSubcomponent$AsyncFooNullable$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i1.AsyncFoo? get() => _module.provideChildAsyncFoo();
}

class _SessionSubcomponent$SyncFooNullable$Provider
    implements _i3.Provider<_i2.Future<_i1.SyncFoo?>> {
  const _SessionSubcomponent$SyncFooNullable$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i2.Future<_i1.SyncFoo?> get() => _module.provideChildSyncFoo();
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

class _SyncFoo$Provider implements _i3.Provider<_i1.SyncFoo> {
  const _SyncFoo$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.SyncFoo get() => _module.provideSyncFoo();
}

class _SyncFooReader$Provider implements _i3.Provider<_i1.SyncFooReader> {
  const _SyncFooReader$Provider(this._syncFoo$Provider);

  final _SyncFoo$Provider _syncFoo$Provider;

  @override
  _i1.SyncFooReader get() => _i1.SyncFooReader(_syncFoo$Provider.get());
}
