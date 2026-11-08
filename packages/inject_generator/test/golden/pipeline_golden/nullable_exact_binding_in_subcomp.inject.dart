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

import 'nullable_exact_binding_in_subcomp.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _bar$Provider = _Bar$Provider(appModule);
    _clockNullable$Provider = _ClockNullable$Provider(appModule);
    _foo$Provider = _Foo$Provider(appModule);
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
  }

  late final _Bar$Provider _bar$Provider;

  late final _ClockNullable$Provider _clockNullable$Provider;

  late final _Foo$Provider _foo$Provider;

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
    required _i1.Timer? timer,
  }) => SessionSubcomponent$Subcomponent._(
    parent,
    sessionModule ?? _i1.SessionModule(),
    timer,
  );

  SessionSubcomponent$Subcomponent._(
    this._parent,
    _i1.SessionModule sessionModule,
    this.timer,
  ) {
    _sessionSubcomponent$asyncView$Provider =
        _SessionSubcomponent$AsyncView$Provider(_parent._bar$Provider);
    final sessionSubcomponent$fooNullable$Provider =
        _SessionSubcomponent$FooNullable$Provider(sessionModule);
    _sessionSubcomponent$timerNullable$Provider =
        _SessionSubcomponent$TimerNullable$Provider(timer);
    final sessionSubcomponent$reportBuilder$Provider =
        _SessionSubcomponent$ReportBuilder$Provider(
          _parent._clockNullable$Provider,
          sessionSubcomponent$fooNullable$Provider,
          _sessionSubcomponent$timerNullable$Provider,
        );
    _sessionSubcomponent$sessionPageFactory$Provider =
        _SessionSubcomponent$SessionPageFactory$Provider(
          _parent._clockNullable$Provider,
          sessionSubcomponent$fooNullable$Provider,
          _sessionSubcomponent$timerNullable$Provider,
          sessionSubcomponent$reportBuilder$Provider,
        );
    _sessionSubcomponent$sessionView$Provider =
        _SessionSubcomponent$SessionView$Provider(
          _parent._clockNullable$Provider,
          _parent._foo$Provider,
          sessionSubcomponent$fooNullable$Provider,
          _sessionSubcomponent$timerNullable$Provider,
        );
    _sessionSubcomponent$string$Provider = _SessionSubcomponent$String$Provider(
      _parent._clockNullable$Provider,
      sessionSubcomponent$fooNullable$Provider,
      _sessionSubcomponent$timerNullable$Provider,
      sessionModule,
    );
  }

  final AppComponent$Component _parent;

  final _i1.Timer? timer;

  late final _SessionSubcomponent$AsyncView$Provider
  _sessionSubcomponent$asyncView$Provider;

  late final _SessionSubcomponent$TimerNullable$Provider
  _sessionSubcomponent$timerNullable$Provider;

  late final _SessionSubcomponent$SessionPageFactory$Provider
  _sessionSubcomponent$sessionPageFactory$Provider;

  late final _SessionSubcomponent$SessionView$Provider
  _sessionSubcomponent$sessionView$Provider;

  late final _SessionSubcomponent$String$Provider
  _sessionSubcomponent$string$Provider;

  @override
  _i2.Future<_i1.AsyncView> get asyncView =>
      _sessionSubcomponent$asyncView$Provider.get();

  @override
  _i1.SessionPageFactory get sessionPageFactory =>
      _sessionSubcomponent$sessionPageFactory$Provider.get();

  @override
  _i1.SessionView get sessionView =>
      _sessionSubcomponent$sessionView$Provider.get();

  @override
  String get label => _sessionSubcomponent$string$Provider.get();
}

class _SessionSubcomponentFactory$Factory
    implements _i1.SessionSubcomponentFactory {
  const _SessionSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.SessionSubcomponent create(_i1.Timer? timer) =>
      SessionSubcomponent$Subcomponent.create(_parent, timer: timer);
}

class _Bar$Provider implements _i3.Provider<_i2.Future<_i1.Bar>> {
  const _Bar$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i2.Future<_i1.Bar> get() => _module.provideBar();
}

class _ClockNullable$Provider implements _i3.Provider<_i1.Clock?> {
  const _ClockNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Clock? get() => _module.provideClock();
}

class _Foo$Provider implements _i3.Provider<_i1.Foo> {
  const _Foo$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Foo get() => _module.provideFoo();
}

class _SessionSubcomponent$AsyncView$Provider
    implements _i3.Provider<_i2.Future<_i1.AsyncView>> {
  const _SessionSubcomponent$AsyncView$Provider(this._bar$Provider);

  final _Bar$Provider _bar$Provider;

  @override
  _i2.Future<_i1.AsyncView> get() async =>
      _i1.AsyncView(await (_bar$Provider.get()));
}

class _SessionSubcomponent$FooNullable$Provider
    implements _i3.Provider<_i1.Foo?> {
  const _SessionSubcomponent$FooNullable$Provider(this._module);

  final _i1.SessionModule _module;

  @override
  _i1.Foo? get() => _module.provideMaybeFoo();
}

class _SessionSubcomponent$ReportBuilder$Provider
    implements _i3.Provider<_i1.ReportBuilder> {
  const _SessionSubcomponent$ReportBuilder$Provider(
    this._clockNullable$Provider,
    this._sessionSubcomponent$fooNullable$Provider,
    this._sessionSubcomponent$timerNullable$Provider,
  );

  final _ClockNullable$Provider _clockNullable$Provider;

  final _SessionSubcomponent$FooNullable$Provider
  _sessionSubcomponent$fooNullable$Provider;

  final _SessionSubcomponent$TimerNullable$Provider
  _sessionSubcomponent$timerNullable$Provider;

  @override
  _i1.ReportBuilder get() =>
      (String title) => _i1.Report(
        title,
        _clockNullable$Provider.get(),
        _sessionSubcomponent$fooNullable$Provider.get(),
        _sessionSubcomponent$timerNullable$Provider.get(),
      );
}

class _SessionSubcomponent$SessionPageFactory$Factory
    implements _i1.SessionPageFactory {
  const _SessionSubcomponent$SessionPageFactory$Factory(
    this._clockNullable$Provider,
    this._sessionSubcomponent$fooNullable$Provider,
    this._sessionSubcomponent$timerNullable$Provider,
    this._sessionSubcomponent$reportBuilder$Provider,
  );

  final _ClockNullable$Provider _clockNullable$Provider;

  final _SessionSubcomponent$FooNullable$Provider
  _sessionSubcomponent$fooNullable$Provider;

  final _SessionSubcomponent$TimerNullable$Provider
  _sessionSubcomponent$timerNullable$Provider;

  final _SessionSubcomponent$ReportBuilder$Provider
  _sessionSubcomponent$reportBuilder$Provider;

  @override
  _i1.SessionPage create(int id) => _i1.SessionPage(
    _clockNullable$Provider.get(),
    _sessionSubcomponent$fooNullable$Provider.get(),
    _sessionSubcomponent$timerNullable$Provider.get(),
    _sessionSubcomponent$reportBuilder$Provider.get(),
    id,
  );
}

class _SessionSubcomponent$SessionPageFactory$Provider
    implements _i3.Provider<_i1.SessionPageFactory> {
  _SessionSubcomponent$SessionPageFactory$Provider(
    this._clockNullable$Provider,
    this._sessionSubcomponent$fooNullable$Provider,
    this._sessionSubcomponent$timerNullable$Provider,
    this._sessionSubcomponent$reportBuilder$Provider,
  );

  final _ClockNullable$Provider _clockNullable$Provider;

  final _SessionSubcomponent$FooNullable$Provider
  _sessionSubcomponent$fooNullable$Provider;

  final _SessionSubcomponent$TimerNullable$Provider
  _sessionSubcomponent$timerNullable$Provider;

  final _SessionSubcomponent$ReportBuilder$Provider
  _sessionSubcomponent$reportBuilder$Provider;

  late final _i1.SessionPageFactory _factory =
      _SessionSubcomponent$SessionPageFactory$Factory(
        _clockNullable$Provider,
        _sessionSubcomponent$fooNullable$Provider,
        _sessionSubcomponent$timerNullable$Provider,
        _sessionSubcomponent$reportBuilder$Provider,
      );

  @override
  _i1.SessionPageFactory get() => _factory;
}

class _SessionSubcomponent$SessionView$Provider
    implements _i3.Provider<_i1.SessionView> {
  const _SessionSubcomponent$SessionView$Provider(
    this._clockNullable$Provider,
    this._foo$Provider,
    this._sessionSubcomponent$fooNullable$Provider,
    this._sessionSubcomponent$timerNullable$Provider,
  );

  final _ClockNullable$Provider _clockNullable$Provider;

  final _Foo$Provider _foo$Provider;

  final _SessionSubcomponent$FooNullable$Provider
  _sessionSubcomponent$fooNullable$Provider;

  final _SessionSubcomponent$TimerNullable$Provider
  _sessionSubcomponent$timerNullable$Provider;

  @override
  _i1.SessionView get() => _i1.SessionView(
    _clockNullable$Provider.get(),
    _foo$Provider.get(),
    _sessionSubcomponent$fooNullable$Provider.get(),
    _sessionSubcomponent$timerNullable$Provider.get(),
  );
}

class _SessionSubcomponent$String$Provider implements _i3.Provider<String> {
  const _SessionSubcomponent$String$Provider(
    this._clockNullable$Provider,
    this._sessionSubcomponent$fooNullable$Provider,
    this._sessionSubcomponent$timerNullable$Provider,
    this._module,
  );

  final _ClockNullable$Provider _clockNullable$Provider;

  final _SessionSubcomponent$FooNullable$Provider
  _sessionSubcomponent$fooNullable$Provider;

  final _SessionSubcomponent$TimerNullable$Provider
  _sessionSubcomponent$timerNullable$Provider;

  final _i1.SessionModule _module;

  @override
  String get() => _module.provideLabel(
    _clockNullable$Provider.get(),
    _sessionSubcomponent$fooNullable$Provider.get(),
    _sessionSubcomponent$timerNullable$Provider.get(),
  );
}

class _SessionSubcomponent$TimerNullable$Provider
    implements _i3.Provider<_i1.Timer?> {
  const _SessionSubcomponent$TimerNullable$Provider(this._value);

  final _i1.Timer? _value;

  @override
  _i1.Timer? get() => _value;
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
