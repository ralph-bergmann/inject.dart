// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'subcomp_value_param_inject_class.dart' as _i1;

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
    required _i1.Clock clock,
  }) => SessionSubcomponent$Subcomponent._(parent, clock);

  SessionSubcomponent$Subcomponent._(this._parent, this.clock) {
    _sessionSubcomponent$clock$Provider = _SessionSubcomponent$Clock$Provider(
      clock,
    );
    _sessionSubcomponent$sessionView$Provider =
        _SessionSubcomponent$SessionView$Provider(
          _sessionSubcomponent$clock$Provider,
        );
  }

  final AppComponent$Component _parent;

  final _i1.Clock clock;

  late final _SessionSubcomponent$Clock$Provider
  _sessionSubcomponent$clock$Provider;

  late final _SessionSubcomponent$SessionView$Provider
  _sessionSubcomponent$sessionView$Provider;

  @override
  _i1.SessionView get sessionView =>
      _sessionSubcomponent$sessionView$Provider.get();
}

class _SessionSubcomponentFactory$Factory
    implements _i1.SessionSubcomponentFactory {
  const _SessionSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.SessionSubcomponent create(_i1.Clock clock) =>
      SessionSubcomponent$Subcomponent.create(_parent, clock: clock);
}

class _SessionSubcomponent$Clock$Provider implements _i2.Provider<_i1.Clock> {
  const _SessionSubcomponent$Clock$Provider(this._value);

  final _i1.Clock _value;

  @override
  _i1.Clock get() => _value;
}

class _SessionSubcomponent$SessionView$Provider
    implements _i2.Provider<_i1.SessionView> {
  const _SessionSubcomponent$SessionView$Provider(
    this._sessionSubcomponent$clock$Provider,
  );

  final _SessionSubcomponent$Clock$Provider _sessionSubcomponent$clock$Provider;

  @override
  _i1.SessionView get() =>
      _i1.SessionView(_sessionSubcomponent$clock$Provider.get());
}

class _SessionSubcomponentFactory$Provider
    implements _i2.Provider<_i1.SessionSubcomponentFactory> {
  _SessionSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.SessionSubcomponentFactory _factory =
      _SessionSubcomponentFactory$Factory(_parent);

  @override
  _i1.SessionSubcomponentFactory get() => _factory;
}
