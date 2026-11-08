// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'typedef_provider_extra_param_shapes.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _clock$Provider = _Clock$Provider();
    final abstractFactoryBuilder$Provider = _AbstractFactoryBuilder$Provider(
      _clock$Provider,
    );
    final firstTwin$Provider = _FirstTwin$Provider(_clock$Provider);
    final mixedBuilder$Provider = _MixedBuilder$Provider(_clock$Provider);
    final nullableBuilder$Provider = _NullableBuilder$Provider(_clock$Provider);
    final repeatedBuilder$Provider = _RepeatedBuilder$Provider(_clock$Provider);
    final qClockPrimary$Provider = _QClockPrimary$Provider();
    final qualifiedBuilder$Provider = _QualifiedBuilder$Provider(
      qClockPrimary$Provider,
    );
    final secondTwin$Provider = _SecondTwin$Provider(_clock$Provider);
    _pageFactory$Provider = _PageFactory$Provider(
      nullableBuilder$Provider,
      repeatedBuilder$Provider,
      mixedBuilder$Provider,
      qualifiedBuilder$Provider,
      firstTwin$Provider,
      secondTwin$Provider,
      abstractFactoryBuilder$Provider,
    );
    _repeatedInjectable$Provider = _RepeatedInjectable$Provider(
      _clock$Provider,
    );
    _repeatedProvided$Provider = _RepeatedProvided$Provider(
      _clock$Provider,
      appModule,
    );
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
  }

  late final _Clock$Provider _clock$Provider;

  late final _PageFactory$Provider _pageFactory$Provider;

  late final _RepeatedInjectable$Provider _repeatedInjectable$Provider;

  late final _RepeatedProvided$Provider _repeatedProvided$Provider;

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

  @override
  _i1.PageFactory get pageFactory => _pageFactory$Provider.get();

  @override
  _i1.RepeatedInjectable get repeatedInjectable =>
      _repeatedInjectable$Provider.get();

  @override
  _i1.RepeatedProvided get repeatedProvided => _repeatedProvided$Provider.get();

  @override
  _i1.SessionSubcomponentFactory get sessionFactory =>
      _sessionSubcomponentFactory$Provider.get();
}

class SessionSubcomponent$Subcomponent implements _i1.SessionSubcomponent {
  factory SessionSubcomponent$Subcomponent.create(
    AppComponent$Component parent,
  ) => SessionSubcomponent$Subcomponent._(parent);

  SessionSubcomponent$Subcomponent._(this._parent) {
    final sessionSubcomponent$childMixedBuilder$Provider =
        _SessionSubcomponent$ChildMixedBuilder$Provider(
          _parent._clock$Provider,
        );
    _sessionSubcomponent$sessionViewFactory$Provider =
        _SessionSubcomponent$SessionViewFactory$Provider(
          sessionSubcomponent$childMixedBuilder$Provider,
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

class _AbstractFactoryBuilder$Provider
    implements _i2.Provider<_i1.AbstractFactoryBuilder> {
  const _AbstractFactoryBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.AbstractFactoryBuilder get() =>
      (String name) => _i1.AbstractFactoryBuilt(name, _clock$Provider.get());
}

class _Clock$Provider implements _i2.Provider<_i1.Clock> {
  const _Clock$Provider();

  @override
  _i1.Clock get() => _i1.Clock();
}

class _FirstTwin$Provider implements _i2.Provider<_i1.FirstTwin> {
  const _FirstTwin$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.FirstTwin get() =>
      (String name) => _i1.Twin(name, _clock$Provider.get());
}

class _MixedBuilder$Provider implements _i2.Provider<_i1.MixedBuilder> {
  const _MixedBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.MixedBuilder get() =>
      (String name) =>
          _i1.MixedBuilt(name, _clock$Provider.get(), _clock$Provider.get());
}

class _NullableBuilder$Provider implements _i2.Provider<_i1.NullableBuilder> {
  const _NullableBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.NullableBuilder get() =>
      (String name) => _i1.NullableBuilt(name, _clock$Provider.get());
}

class _PageFactory$Factory implements _i1.PageFactory {
  const _PageFactory$Factory(
    this._nullableBuilder$Provider,
    this._repeatedBuilder$Provider,
    this._mixedBuilder$Provider,
    this._qualifiedBuilder$Provider,
    this._firstTwin$Provider,
    this._secondTwin$Provider,
    this._abstractFactoryBuilder$Provider,
  );

  final _NullableBuilder$Provider _nullableBuilder$Provider;

  final _RepeatedBuilder$Provider _repeatedBuilder$Provider;

  final _MixedBuilder$Provider _mixedBuilder$Provider;

  final _QualifiedBuilder$Provider _qualifiedBuilder$Provider;

  final _FirstTwin$Provider _firstTwin$Provider;

  final _SecondTwin$Provider _secondTwin$Provider;

  final _AbstractFactoryBuilder$Provider _abstractFactoryBuilder$Provider;

  @override
  _i1.Page create(String title) => _i1.Page(
    _nullableBuilder$Provider.get(),
    _repeatedBuilder$Provider.get(),
    _mixedBuilder$Provider.get(),
    _qualifiedBuilder$Provider.get(),
    _firstTwin$Provider.get(),
    _secondTwin$Provider.get(),
    _abstractFactoryBuilder$Provider.get(),
    title,
  );
}

class _PageFactory$Provider implements _i2.Provider<_i1.PageFactory> {
  _PageFactory$Provider(
    this._nullableBuilder$Provider,
    this._repeatedBuilder$Provider,
    this._mixedBuilder$Provider,
    this._qualifiedBuilder$Provider,
    this._firstTwin$Provider,
    this._secondTwin$Provider,
    this._abstractFactoryBuilder$Provider,
  );

  final _NullableBuilder$Provider _nullableBuilder$Provider;

  final _RepeatedBuilder$Provider _repeatedBuilder$Provider;

  final _MixedBuilder$Provider _mixedBuilder$Provider;

  final _QualifiedBuilder$Provider _qualifiedBuilder$Provider;

  final _FirstTwin$Provider _firstTwin$Provider;

  final _SecondTwin$Provider _secondTwin$Provider;

  final _AbstractFactoryBuilder$Provider _abstractFactoryBuilder$Provider;

  late final _i1.PageFactory _factory = _PageFactory$Factory(
    _nullableBuilder$Provider,
    _repeatedBuilder$Provider,
    _mixedBuilder$Provider,
    _qualifiedBuilder$Provider,
    _firstTwin$Provider,
    _secondTwin$Provider,
    _abstractFactoryBuilder$Provider,
  );

  @override
  _i1.PageFactory get() => _factory;
}

class _QClockPrimary$Provider implements _i2.Provider<_i1.QClock> {
  const _QClockPrimary$Provider();

  @override
  _i1.QClock get() => _i1.QClock.first();
}

class _QualifiedBuilder$Provider implements _i2.Provider<_i1.QualifiedBuilder> {
  const _QualifiedBuilder$Provider(this._qClockPrimary$Provider);

  final _QClockPrimary$Provider _qClockPrimary$Provider;

  @override
  _i1.QualifiedBuilder get() =>
      (String name) => _i1.QualifiedBuilt(name, _qClockPrimary$Provider.get());
}

class _RepeatedBuilder$Provider implements _i2.Provider<_i1.RepeatedBuilder> {
  const _RepeatedBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.RepeatedBuilder get() =>
      (String name) =>
          _i1.RepeatedBuilt(name, _clock$Provider.get(), _clock$Provider.get());
}

class _RepeatedInjectable$Provider
    implements _i2.Provider<_i1.RepeatedInjectable> {
  const _RepeatedInjectable$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.RepeatedInjectable get() =>
      _i1.RepeatedInjectable(_clock$Provider.get(), _clock$Provider.get());
}

class _RepeatedProvided$Provider implements _i2.Provider<_i1.RepeatedProvided> {
  const _RepeatedProvided$Provider(this._clock$Provider, this._module);

  final _Clock$Provider _clock$Provider;

  final _i1.AppModule _module;

  @override
  _i1.RepeatedProvided get() =>
      _module.provideRepeated(_clock$Provider.get(), _clock$Provider.get());
}

class _SecondTwin$Provider implements _i2.Provider<_i1.SecondTwin> {
  const _SecondTwin$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.SecondTwin get() =>
      (String name) => _i1.Twin(name, _clock$Provider.get());
}

class _SessionSubcomponent$ChildMixedBuilder$Provider
    implements _i2.Provider<_i1.ChildMixedBuilder> {
  const _SessionSubcomponent$ChildMixedBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.ChildMixedBuilder get() =>
      (String name) => _i1.ChildMixedBuilt(
        name,
        _clock$Provider.get(),
        _clock$Provider.get(),
      );
}

class _SessionSubcomponent$SessionViewFactory$Factory
    implements _i1.SessionViewFactory {
  const _SessionSubcomponent$SessionViewFactory$Factory(
    this._sessionSubcomponent$childMixedBuilder$Provider,
  );

  final _SessionSubcomponent$ChildMixedBuilder$Provider
  _sessionSubcomponent$childMixedBuilder$Provider;

  @override
  _i1.SessionView create(String userId) => _i1.SessionView(
    _sessionSubcomponent$childMixedBuilder$Provider.get(),
    userId,
  );
}

class _SessionSubcomponent$SessionViewFactory$Provider
    implements _i2.Provider<_i1.SessionViewFactory> {
  _SessionSubcomponent$SessionViewFactory$Provider(
    this._sessionSubcomponent$childMixedBuilder$Provider,
  );

  final _SessionSubcomponent$ChildMixedBuilder$Provider
  _sessionSubcomponent$childMixedBuilder$Provider;

  late final _i1.SessionViewFactory _factory =
      _SessionSubcomponent$SessionViewFactory$Factory(
        _sessionSubcomponent$childMixedBuilder$Provider,
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
