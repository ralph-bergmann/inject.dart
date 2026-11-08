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

import 'nullable_child_shadows_parent.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _childAsyncDepNullable$Provider = _ChildAsyncDepNullable$Provider(
      appModule,
    );
    _childAsyncValueNullable$Provider = _ChildAsyncValueNullable$Provider(
      appModule,
    );
    _childSyncDepNullable$Provider = _ChildSyncDepNullable$Provider(appModule);
    _childSyncValueNullable$Provider = _ChildSyncValueNullable$Provider(
      appModule,
    );
    _sharedDepNullable$Provider = _SharedDepNullable$Provider(appModule);
    _parentReader$Provider = _ParentReader$Provider(
      _sharedDepNullable$Provider,
    );
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
  }

  late final _ChildAsyncDepNullable$Provider _childAsyncDepNullable$Provider;

  late final _ChildAsyncValueNullable$Provider
  _childAsyncValueNullable$Provider;

  late final _ChildSyncDepNullable$Provider _childSyncDepNullable$Provider;

  late final _ChildSyncValueNullable$Provider _childSyncValueNullable$Provider;

  late final _SharedDepNullable$Provider _sharedDepNullable$Provider;

  late final _ParentReader$Provider _parentReader$Provider;

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

  @override
  _i1.ChildAsyncDep? get parentAsyncDep =>
      _childAsyncDepNullable$Provider.get();

  @override
  _i1.ChildAsyncValue? get parentAsyncValue =>
      _childAsyncValueNullable$Provider.get();

  @override
  _i2.Future<_i1.ChildSyncDep?> get parentSyncDep =>
      _childSyncDepNullable$Provider.get();

  @override
  _i2.Future<_i1.ChildSyncValue?> get parentSyncValue =>
      _childSyncValueNullable$Provider.get();

  @override
  _i1.SharedDep? get parentSharedDep => _sharedDepNullable$Provider.get();

  @override
  _i1.ParentReader get parentReader => _parentReader$Provider.get();

  @override
  _i1.SessionSubcomponentFactory get sessionFactory =>
      _sessionSubcomponentFactory$Provider.get();
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
    final sessionSubcomponent$childAsyncDep$Provider =
        _SessionSubcomponent$ChildAsyncDep$Provider(sessionModule);
    _sessionSubcomponent$asyncView$Provider =
        _SessionSubcomponent$AsyncView$Provider(
          sessionSubcomponent$childAsyncDep$Provider,
        );
    _sessionSubcomponent$childAsyncValue$Provider =
        _SessionSubcomponent$ChildAsyncValue$Provider(sessionModule);
    final sessionSubcomponent$childSyncDep$Provider =
        _SessionSubcomponent$ChildSyncDep$Provider(sessionModule);
    _sessionSubcomponent$childSyncValue$Provider =
        _SessionSubcomponent$ChildSyncValue$Provider(sessionModule);
    _sessionSubcomponent$sharedDep$Provider =
        _SessionSubcomponent$SharedDep$Provider(sessionModule);
    _sessionSubcomponent$syncView$Provider =
        _SessionSubcomponent$SyncView$Provider(
          sessionSubcomponent$childSyncDep$Provider,
        );
  }

  final AppComponent$Component _parent;

  late final _SessionSubcomponent$AsyncView$Provider
  _sessionSubcomponent$asyncView$Provider;

  late final _SessionSubcomponent$ChildAsyncValue$Provider
  _sessionSubcomponent$childAsyncValue$Provider;

  late final _SessionSubcomponent$ChildSyncValue$Provider
  _sessionSubcomponent$childSyncValue$Provider;

  late final _SessionSubcomponent$SharedDep$Provider
  _sessionSubcomponent$sharedDep$Provider;

  late final _SessionSubcomponent$SyncView$Provider
  _sessionSubcomponent$syncView$Provider;

  @override
  _i2.Future<_i1.AsyncView> get asyncView =>
      _sessionSubcomponent$asyncView$Provider.get();

  @override
  _i2.Future<_i1.ChildAsyncValue?> get childAsyncValue =>
      _sessionSubcomponent$childAsyncValue$Provider.get();

  @override
  _i1.ChildSyncValue? get childSyncValue =>
      _sessionSubcomponent$childSyncValue$Provider.get();

  @override
  _i2.Future<_i1.SharedDep> get sharedDep =>
      _sessionSubcomponent$sharedDep$Provider.get();

  @override
  _i1.SyncView get syncView => _sessionSubcomponent$syncView$Provider.get();

  @override
  _i1.ParentReader get parentReader => _parent._parentReader$Provider.get();
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

class _ChildAsyncDepNullable$Provider
    implements _i3.Provider<_i1.ChildAsyncDep?> {
  const _ChildAsyncDepNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.ChildAsyncDep? get() => _module.provideParentAsyncDep();
}

class _ChildAsyncValueNullable$Provider
    implements _i3.Provider<_i1.ChildAsyncValue?> {
  const _ChildAsyncValueNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.ChildAsyncValue? get() => _module.provideParentAsyncValue();
}

class _ChildSyncDepNullable$Provider
    implements _i3.Provider<_i2.Future<_i1.ChildSyncDep?>> {
  const _ChildSyncDepNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.ChildSyncDep?> get() => _module.provideParentSyncDep();
}

class _ChildSyncValueNullable$Provider
    implements _i3.Provider<_i2.Future<_i1.ChildSyncValue?>> {
  const _ChildSyncValueNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.ChildSyncValue?> get() => _module.provideParentSyncValue();
}

class _ParentReader$Provider implements _i3.Provider<_i1.ParentReader> {
  const _ParentReader$Provider(this._sharedDepNullable$Provider);

  final _SharedDepNullable$Provider _sharedDepNullable$Provider;

  @override
  _i1.ParentReader get() => _i1.ParentReader(_sharedDepNullable$Provider.get());
}

class _SessionSubcomponent$AsyncView$Provider
    implements _i3.Provider<_i2.Future<_i1.AsyncView>> {
  const _SessionSubcomponent$AsyncView$Provider(
    this._sessionSubcomponent$childAsyncDep$Provider,
  );

  final _SessionSubcomponent$ChildAsyncDep$Provider
  _sessionSubcomponent$childAsyncDep$Provider;

  @override
  _i2.Future<_i1.AsyncView> get() async =>
      _i1.AsyncView(await (_sessionSubcomponent$childAsyncDep$Provider.get()));
}

class _SessionSubcomponent$ChildAsyncDep$Provider
    implements _i3.Provider<_i2.Future<_i1.ChildAsyncDep>> {
  const _SessionSubcomponent$ChildAsyncDep$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i2.Future<_i1.ChildAsyncDep> get() => _module.provideChildAsyncDep();
}

class _SessionSubcomponent$ChildAsyncValue$Provider
    implements _i3.Provider<_i2.Future<_i1.ChildAsyncValue>> {
  const _SessionSubcomponent$ChildAsyncValue$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i2.Future<_i1.ChildAsyncValue> get() => _module.provideChildAsyncValue();
}

class _SessionSubcomponent$ChildSyncDep$Provider
    implements _i3.Provider<_i1.ChildSyncDep> {
  const _SessionSubcomponent$ChildSyncDep$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i1.ChildSyncDep get() => _module.provideChildSyncDep();
}

class _SessionSubcomponent$ChildSyncValue$Provider
    implements _i3.Provider<_i1.ChildSyncValue> {
  const _SessionSubcomponent$ChildSyncValue$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i1.ChildSyncValue get() => _module.provideChildSyncValue();
}

class _SessionSubcomponent$SharedDep$Provider
    implements _i3.Provider<_i2.Future<_i1.SharedDep>> {
  const _SessionSubcomponent$SharedDep$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i2.Future<_i1.SharedDep> get() => _module.provideChildSharedDep();
}

class _SessionSubcomponent$SyncView$Provider
    implements _i3.Provider<_i1.SyncView> {
  const _SessionSubcomponent$SyncView$Provider(
    this._sessionSubcomponent$childSyncDep$Provider,
  );

  final _SessionSubcomponent$ChildSyncDep$Provider
  _sessionSubcomponent$childSyncDep$Provider;

  @override
  _i1.SyncView get() =>
      _i1.SyncView(_sessionSubcomponent$childSyncDep$Provider.get());
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

class _SharedDepNullable$Provider implements _i3.Provider<_i1.SharedDep?> {
  const _SharedDepNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.SharedDep? get() => _module.provideParentSharedDep();
}
