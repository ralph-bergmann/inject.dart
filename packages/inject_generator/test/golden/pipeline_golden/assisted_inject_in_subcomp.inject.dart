// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'assisted_inject_in_subcomp.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _authSubcomponentFactory$Provider = _AuthSubcomponentFactory$Provider(this);
    _logger$Provider = _Logger$Provider();
  }

  late final _AuthSubcomponentFactory$Provider
  _authSubcomponentFactory$Provider;

  late final _Logger$Provider _logger$Provider;

  @override
  _i1.AuthSubcomponentFactory get authFactory =>
      _authSubcomponentFactory$Provider.get();

  @override
  _i1.Logger get logger => _logger$Provider.get();
}

class AuthSubcomponent$Subcomponent implements _i1.AuthSubcomponent {
  factory AuthSubcomponent$Subcomponent.create(AppComponent$Component parent) =>
      AuthSubcomponent$Subcomponent._(parent);

  AuthSubcomponent$Subcomponent._(this._parent) {
    _authSubcomponent$sessionFactory$Provider =
        _AuthSubcomponent$SessionFactory$Provider(_parent._logger$Provider);
  }

  final AppComponent$Component _parent;

  late final _AuthSubcomponent$SessionFactory$Provider
  _authSubcomponent$sessionFactory$Provider;

  @override
  _i1.SessionFactory get sessionFactory =>
      _authSubcomponent$sessionFactory$Provider.get();
}

class _AuthSubcomponentFactory$Factory implements _i1.AuthSubcomponentFactory {
  const _AuthSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.AuthSubcomponent create() =>
      AuthSubcomponent$Subcomponent.create(_parent);
}

class _AuthSubcomponent$SessionFactory$Factory implements _i1.SessionFactory {
  const _AuthSubcomponent$SessionFactory$Factory(this._logger$Provider);

  final _Logger$Provider _logger$Provider;

  @override
  _i1.Session create(String userId) =>
      _i1.Session(_logger$Provider.get(), userId);
}

class _AuthSubcomponent$SessionFactory$Provider
    implements _i2.Provider<_i1.SessionFactory> {
  _AuthSubcomponent$SessionFactory$Provider(this._logger$Provider);

  final _Logger$Provider _logger$Provider;

  late final _i1.SessionFactory _factory =
      _AuthSubcomponent$SessionFactory$Factory(_logger$Provider);

  @override
  _i1.SessionFactory get() => _factory;
}

class _AuthSubcomponentFactory$Provider
    implements _i2.Provider<_i1.AuthSubcomponentFactory> {
  _AuthSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.AuthSubcomponentFactory _factory =
      _AuthSubcomponentFactory$Factory(_parent);

  @override
  _i1.AuthSubcomponentFactory get() => _factory;
}

class _Logger$Provider implements _i2.Provider<_i1.Logger> {
  _Logger$Provider();

  late final _i1.Logger _singleton = _create();

  _i1.Logger _create() => _i1.Logger();

  @override
  _i1.Logger get() => _singleton;
}
