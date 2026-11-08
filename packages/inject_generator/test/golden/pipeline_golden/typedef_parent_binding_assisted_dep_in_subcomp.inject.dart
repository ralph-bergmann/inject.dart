// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'typedef_parent_binding_assisted_dep_in_subcomp.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final clock$Provider = _Clock$Provider();
    _badgeBuilder$Provider = _BadgeBuilder$Provider(clock$Provider);
    _dashboardFactory$Provider = _DashboardFactory$Provider(
      _badgeBuilder$Provider,
    );
    _greetingBuilder$Provider = _GreetingBuilder$Provider(appModule);
    _loadCount$Provider = _LoadCount$Provider(appModule);
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
  }

  late final _BadgeBuilder$Provider _badgeBuilder$Provider;

  late final _DashboardFactory$Provider _dashboardFactory$Provider;

  late final _GreetingBuilder$Provider _greetingBuilder$Provider;

  late final _LoadCount$Provider _loadCount$Provider;

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

  @override
  _i1.DashboardFactory get dashboardFactory => _dashboardFactory$Provider.get();

  @override
  _i1.SessionSubcomponentFactory get sessionSubcomponentFactory =>
      _sessionSubcomponentFactory$Provider.get();
}

class SessionSubcomponent$Subcomponent implements _i1.SessionSubcomponent {
  factory SessionSubcomponent$Subcomponent.create(
    AppComponent$Component parent,
  ) => SessionSubcomponent$Subcomponent._(parent);

  SessionSubcomponent$Subcomponent._(this._parent) {
    _sessionSubcomponent$sessionViewFactory$Provider =
        _SessionSubcomponent$SessionViewFactory$Provider(
          _parent._loadCount$Provider,
          _parent._greetingBuilder$Provider,
          _parent._badgeBuilder$Provider,
        );
  }

  final AppComponent$Component _parent;

  late final _SessionSubcomponent$SessionViewFactory$Provider
  _sessionSubcomponent$sessionViewFactory$Provider;

  @override
  _i1.SessionViewFactory get sessionViewFactory =>
      _sessionSubcomponent$sessionViewFactory$Provider.get();
}

class _SessionSubcomponentFactory$Factory
    implements _i1.SessionSubcomponentFactory {
  const _SessionSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.SessionSubcomponent create() =>
      SessionSubcomponent$Subcomponent.create(_parent);
}

class _BadgeBuilder$Provider implements _i2.Provider<_i1.BadgeBuilder> {
  const _BadgeBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.BadgeBuilder get() =>
      (String label) => _i1.Badge(label, _clock$Provider.get());
}

class _Clock$Provider implements _i2.Provider<_i1.Clock> {
  const _Clock$Provider();

  @override
  _i1.Clock get() => _i1.Clock();
}

class _DashboardFactory$Factory implements _i1.DashboardFactory {
  const _DashboardFactory$Factory(this._badgeBuilder$Provider);

  final _BadgeBuilder$Provider _badgeBuilder$Provider;

  @override
  _i1.Dashboard create(String title) =>
      _i1.Dashboard(_badgeBuilder$Provider.get(), title);
}

class _DashboardFactory$Provider implements _i2.Provider<_i1.DashboardFactory> {
  _DashboardFactory$Provider(this._badgeBuilder$Provider);

  final _BadgeBuilder$Provider _badgeBuilder$Provider;

  late final _i1.DashboardFactory _factory = _DashboardFactory$Factory(
    _badgeBuilder$Provider,
  );

  @override
  _i1.DashboardFactory get() => _factory;
}

class _GreetingBuilder$Provider implements _i2.Provider<_i1.GreetingBuilder> {
  const _GreetingBuilder$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.GreetingBuilder get() => _module.provideGreetingBuilder();
}

class _LoadCount$Provider implements _i2.Provider<_i1.LoadCount> {
  const _LoadCount$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.LoadCount get() => _module.provideLoadCount();
}

class _SessionSubcomponent$SessionViewFactory$Factory
    implements _i1.SessionViewFactory {
  const _SessionSubcomponent$SessionViewFactory$Factory(
    this._loadCount$Provider,
    this._greetingBuilder$Provider,
    this._badgeBuilder$Provider,
  );

  final _LoadCount$Provider _loadCount$Provider;

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  final _BadgeBuilder$Provider _badgeBuilder$Provider;

  @override
  _i1.SessionView create(String userId) => _i1.SessionView(
    _loadCount$Provider.get(),
    _greetingBuilder$Provider.get(),
    _badgeBuilder$Provider.get(),
    userId,
  );
}

class _SessionSubcomponent$SessionViewFactory$Provider
    implements _i2.Provider<_i1.SessionViewFactory> {
  _SessionSubcomponent$SessionViewFactory$Provider(
    this._loadCount$Provider,
    this._greetingBuilder$Provider,
    this._badgeBuilder$Provider,
  );

  final _LoadCount$Provider _loadCount$Provider;

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  final _BadgeBuilder$Provider _badgeBuilder$Provider;

  late final _i1.SessionViewFactory _factory =
      _SessionSubcomponent$SessionViewFactory$Factory(
        _loadCount$Provider,
        _greetingBuilder$Provider,
        _badgeBuilder$Provider,
      );

  @override
  _i1.SessionViewFactory get() => _factory;
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
