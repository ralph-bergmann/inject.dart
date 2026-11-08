// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nullable_dep_bound_inject_class.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _clock$Provider = _Clock$Provider(appModule);
    _dashboard$Provider = _Dashboard$Provider(_clock$Provider);
    _pageFactory$Provider = _PageFactory$Provider(_clock$Provider);
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
    _string$Provider = _String$Provider(_clock$Provider, appModule);
  }

  late final _Clock$Provider _clock$Provider;

  late final _Dashboard$Provider _dashboard$Provider;

  late final _PageFactory$Provider _pageFactory$Provider;

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

  late final _String$Provider _string$Provider;

  @override
  _i1.Dashboard get dashboard => _dashboard$Provider.get();

  @override
  _i1.PageFactory get pageFactory => _pageFactory$Provider.get();

  @override
  _i1.SessionSubcomponentFactory get sessionFactory =>
      _sessionSubcomponentFactory$Provider.get();

  @override
  String get label => _string$Provider.get();
}

class SessionSubcomponent$Subcomponent implements _i1.SessionSubcomponent {
  factory SessionSubcomponent$Subcomponent.create(
    AppComponent$Component parent,
  ) => SessionSubcomponent$Subcomponent._(parent);

  SessionSubcomponent$Subcomponent._(this._parent) {
    _sessionSubcomponent$sessionView$Provider =
        _SessionSubcomponent$SessionView$Provider(_parent._clock$Provider);
  }

  final AppComponent$Component _parent;

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
  _i1.SessionSubcomponent create() =>
      SessionSubcomponent$Subcomponent.create(_parent);
}

class _Clock$Provider implements _i2.Provider<_i1.Clock> {
  const _Clock$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Clock get() => _module.provideClock();
}

class _Dashboard$Provider implements _i2.Provider<_i1.Dashboard> {
  const _Dashboard$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.Dashboard get() => _i1.Dashboard(_clock$Provider.get());
}

class _PageFactory$Factory implements _i1.PageFactory {
  const _PageFactory$Factory(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.Page create(int id) => _i1.Page(_clock$Provider.get(), id);
}

class _PageFactory$Provider implements _i2.Provider<_i1.PageFactory> {
  _PageFactory$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  late final _i1.PageFactory _factory = _PageFactory$Factory(_clock$Provider);

  @override
  _i1.PageFactory get() => _factory;
}

class _SessionSubcomponent$SessionView$Provider
    implements _i2.Provider<_i1.SessionView> {
  const _SessionSubcomponent$SessionView$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.SessionView get() => _i1.SessionView(_clock$Provider.get());
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

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._clock$Provider, this._module);

  final _Clock$Provider _clock$Provider;

  final _i1.AppModule _module;

  @override
  String get() => _module.provideLabel(_clock$Provider.get());
}
