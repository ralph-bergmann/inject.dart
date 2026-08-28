// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'multi_parent_shared_subcomp.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _appComponent$greeterSubcomponentFactory$Provider =
        _AppComponent$GreeterSubcomponentFactory$Provider(this);
    _appComponent$int$Provider = _AppComponent$Int$Provider(appModule);
  }

  late final _AppComponent$GreeterSubcomponentFactory$Provider
  _appComponent$greeterSubcomponentFactory$Provider;

  late final _AppComponent$Int$Provider _appComponent$int$Provider;

  @override
  _i1.GreeterSubcomponentFactory get greeterFactory =>
      _appComponent$greeterSubcomponentFactory$Provider.get();

  @override
  int get answer => _appComponent$int$Provider.get();
}

class OtherAppComponent$Component implements _i1.OtherAppComponent {
  factory OtherAppComponent$Component.create({
    _i1.OtherAppModule? otherAppModule,
  }) => OtherAppComponent$Component._(otherAppModule ?? _i1.OtherAppModule());

  OtherAppComponent$Component._(_i1.OtherAppModule otherAppModule) {
    _otherAppComponent$greeterSubcomponentFactory$Provider =
        _OtherAppComponent$GreeterSubcomponentFactory$Provider(this);
    _otherAppComponent$string$Provider = _OtherAppComponent$String$Provider(
      otherAppModule,
    );
  }

  late final _OtherAppComponent$GreeterSubcomponentFactory$Provider
  _otherAppComponent$greeterSubcomponentFactory$Provider;

  late final _OtherAppComponent$String$Provider
  _otherAppComponent$string$Provider;

  @override
  _i1.GreeterSubcomponentFactory get greeterFactory =>
      _otherAppComponent$greeterSubcomponentFactory$Provider.get();

  @override
  String get label => _otherAppComponent$string$Provider.get();
}

class AppComponent$GreeterSubcomponent$Subcomponent
    implements _i1.GreeterSubcomponent {
  factory AppComponent$GreeterSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    required _i1.GreeterModule greeterModule,
  }) => AppComponent$GreeterSubcomponent$Subcomponent._(parent, greeterModule);

  AppComponent$GreeterSubcomponent$Subcomponent._(
    this._parent,
    _i1.GreeterModule greeterModule,
  ) {
    _appComponent$GreeterSubcomponent$greeter$Provider =
        _AppComponent$GreeterSubcomponent$Greeter$Provider(greeterModule);
  }

  final AppComponent$Component _parent;

  late final _AppComponent$GreeterSubcomponent$Greeter$Provider
  _appComponent$GreeterSubcomponent$greeter$Provider;

  @override
  _i1.Greeter get greeter =>
      _appComponent$GreeterSubcomponent$greeter$Provider.get();
}

class OtherAppComponent$GreeterSubcomponent$Subcomponent
    implements _i1.GreeterSubcomponent {
  factory OtherAppComponent$GreeterSubcomponent$Subcomponent.create(
    OtherAppComponent$Component parent, {
    required _i1.GreeterModule greeterModule,
  }) => OtherAppComponent$GreeterSubcomponent$Subcomponent._(
    parent,
    greeterModule,
  );

  OtherAppComponent$GreeterSubcomponent$Subcomponent._(
    this._parent,
    _i1.GreeterModule greeterModule,
  ) {
    _otherAppComponent$GreeterSubcomponent$greeter$Provider =
        _OtherAppComponent$GreeterSubcomponent$Greeter$Provider(greeterModule);
  }

  final OtherAppComponent$Component _parent;

  late final _OtherAppComponent$GreeterSubcomponent$Greeter$Provider
  _otherAppComponent$GreeterSubcomponent$greeter$Provider;

  @override
  _i1.Greeter get greeter =>
      _otherAppComponent$GreeterSubcomponent$greeter$Provider.get();
}

class _AppComponent$GreeterSubcomponentFactory$Factory
    implements _i1.GreeterSubcomponentFactory {
  const _AppComponent$GreeterSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.GreeterSubcomponent create({required _i1.GreeterModule greeterModule}) =>
      AppComponent$GreeterSubcomponent$Subcomponent.create(
        _parent,
        greeterModule: greeterModule,
      );
}

class _OtherAppComponent$GreeterSubcomponentFactory$Factory
    implements _i1.GreeterSubcomponentFactory {
  const _OtherAppComponent$GreeterSubcomponentFactory$Factory(this._parent);

  final OtherAppComponent$Component _parent;

  @override
  _i1.GreeterSubcomponent create({required _i1.GreeterModule greeterModule}) =>
      OtherAppComponent$GreeterSubcomponent$Subcomponent.create(
        _parent,
        greeterModule: greeterModule,
      );
}

class _AppComponent$GreeterSubcomponent$Greeter$Provider
    implements _i2.Provider<_i1.Greeter> {
  _AppComponent$GreeterSubcomponent$Greeter$Provider(this._module);

  final _i1.GreeterModule _module;

  late final _i1.Greeter _singleton = _create();

  _i1.Greeter _create() => _module.provideGreeter();

  @override
  _i1.Greeter get() => _singleton;
}

class _AppComponent$GreeterSubcomponentFactory$Provider
    implements _i2.Provider<_i1.GreeterSubcomponentFactory> {
  _AppComponent$GreeterSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.GreeterSubcomponentFactory _factory =
      _AppComponent$GreeterSubcomponentFactory$Factory(_parent);

  @override
  _i1.GreeterSubcomponentFactory get() => _factory;
}

class _AppComponent$Int$Provider implements _i2.Provider<int> {
  const _AppComponent$Int$Provider(this._module);

  final _i1.AppModule _module;

  @override
  int get() => _module.provideAnswer();
}

class _OtherAppComponent$GreeterSubcomponent$Greeter$Provider
    implements _i2.Provider<_i1.Greeter> {
  _OtherAppComponent$GreeterSubcomponent$Greeter$Provider(this._module);

  final _i1.GreeterModule _module;

  late final _i1.Greeter _singleton = _create();

  _i1.Greeter _create() => _module.provideGreeter();

  @override
  _i1.Greeter get() => _singleton;
}

class _OtherAppComponent$GreeterSubcomponentFactory$Provider
    implements _i2.Provider<_i1.GreeterSubcomponentFactory> {
  _OtherAppComponent$GreeterSubcomponentFactory$Provider(this._parent);

  final OtherAppComponent$Component _parent;

  late final _i1.GreeterSubcomponentFactory _factory =
      _OtherAppComponent$GreeterSubcomponentFactory$Factory(_parent);

  @override
  _i1.GreeterSubcomponentFactory get() => _factory;
}

class _OtherAppComponent$String$Provider implements _i2.Provider<String> {
  const _OtherAppComponent$String$Provider(this._module);

  final _i1.OtherAppModule _module;

  @override
  String get() => _module.provideLabel();
}
