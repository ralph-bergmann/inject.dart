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

import 'nullable_child_owns_both_forms.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
  }

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

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
    _sessionSubcomponent$foo$Provider = _SessionSubcomponent$Foo$Provider(
      sessionModule,
    );
    _sessionSubcomponent$fooNullable$Provider =
        _SessionSubcomponent$FooNullable$Provider(sessionModule);
    _sessionSubcomponent$reader$Provider = _SessionSubcomponent$Reader$Provider(
      _sessionSubcomponent$fooNullable$Provider,
    );
  }

  final AppComponent$Component _parent;

  late final _SessionSubcomponent$Foo$Provider
  _sessionSubcomponent$foo$Provider;

  late final _SessionSubcomponent$FooNullable$Provider
  _sessionSubcomponent$fooNullable$Provider;

  late final _SessionSubcomponent$Reader$Provider
  _sessionSubcomponent$reader$Provider;

  @override
  _i2.Future<_i1.Foo> get foo => _sessionSubcomponent$foo$Provider.get();

  @override
  _i1.Foo? get maybeFoo => _sessionSubcomponent$fooNullable$Provider.get();

  @override
  _i1.Reader get reader => _sessionSubcomponent$reader$Provider.get();
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

class _SessionSubcomponent$Foo$Provider
    implements _i3.Provider<_i2.Future<_i1.Foo>> {
  const _SessionSubcomponent$Foo$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i2.Future<_i1.Foo> get() => _module.provideFoo();
}

class _SessionSubcomponent$FooNullable$Provider
    implements _i3.Provider<_i1.Foo?> {
  const _SessionSubcomponent$FooNullable$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i1.Foo? get() => _module.provideMaybeFoo();
}

class _SessionSubcomponent$Reader$Provider implements _i3.Provider<_i1.Reader> {
  const _SessionSubcomponent$Reader$Provider(
    this._sessionSubcomponent$fooNullable$Provider,
  );

  final _SessionSubcomponent$FooNullable$Provider
  _sessionSubcomponent$fooNullable$Provider;

  @override
  _i1.Reader get() =>
      _i1.Reader(_sessionSubcomponent$fooNullable$Provider.get());
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
