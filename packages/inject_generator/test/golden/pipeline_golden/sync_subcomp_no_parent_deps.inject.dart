// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'sync_subcomp_no_parent_deps.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _greeterSubcomponentFactory$Provider = _GreeterSubcomponentFactory$Provider(
      this,
    );
    _int$Provider = _Int$Provider(appModule);
  }

  late final _GreeterSubcomponentFactory$Provider
  _greeterSubcomponentFactory$Provider;

  late final _Int$Provider _int$Provider;

  @override
  _i1.GreeterSubcomponentFactory get greeterFactory =>
      _greeterSubcomponentFactory$Provider.get();

  @override
  int get answer => _int$Provider.get();
}

class GreeterSubcomponent$Subcomponent implements _i1.GreeterSubcomponent {
  factory GreeterSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    required _i1.GreeterModule greeterModule,
  }) => GreeterSubcomponent$Subcomponent._(parent, greeterModule);

  GreeterSubcomponent$Subcomponent._(
    this._parent,
    _i1.GreeterModule greeterModule,
  ) {
    _greeterSubcomponent$greeter$Provider =
        _GreeterSubcomponent$Greeter$Provider(greeterModule);
  }

  final AppComponent$Component _parent;

  late final _GreeterSubcomponent$Greeter$Provider
  _greeterSubcomponent$greeter$Provider;

  @override
  _i1.Greeter get greeter => _greeterSubcomponent$greeter$Provider.get();
}

class _GreeterSubcomponentFactory$Factory
    implements _i1.GreeterSubcomponentFactory {
  const _GreeterSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.GreeterSubcomponent create({required _i1.GreeterModule greeterModule}) =>
      GreeterSubcomponent$Subcomponent.create(
        _parent,
        greeterModule: greeterModule,
      );
}

class _GreeterSubcomponent$Greeter$Provider
    implements _i2.Provider<_i1.Greeter> {
  _GreeterSubcomponent$Greeter$Provider(this._module);

  final _i1.GreeterModule _module;

  late final _i1.Greeter _singleton = _create();

  _i1.Greeter _create() => _module.provideGreeter();

  @override
  _i1.Greeter get() => _singleton;
}

class _GreeterSubcomponentFactory$Provider
    implements _i2.Provider<_i1.GreeterSubcomponentFactory> {
  _GreeterSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.GreeterSubcomponentFactory _factory =
      _GreeterSubcomponentFactory$Factory(_parent);

  @override
  _i1.GreeterSubcomponentFactory get() => _factory;
}

class _Int$Provider implements _i2.Provider<int> {
  const _Int$Provider(this._module);

  final _i1.AppModule _module;

  @override
  int get() => _module.provideAnswer();
}
