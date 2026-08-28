// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'subcomp_provision_listener_scope.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.ParentModule? parentModule}) =>
      AppComponent$Component._(parentModule ?? _i1.ParentModule());

  AppComponent$Component._(_i1.ParentModule parentModule) {
    _childSubcomponentFactory$Provider = _ChildSubcomponentFactory$Provider(
      this,
    );
    final parentListener$Provider = _ParentListener$Provider(parentModule);
    _parentThing$Provider = _ParentThing$Provider(
      parentListener$Provider,
      parentModule,
    );
  }

  late final _ChildSubcomponentFactory$Provider
  _childSubcomponentFactory$Provider;

  late final _ParentThing$Provider _parentThing$Provider;

  @override
  _i1.ChildSubcomponentFactory get childFactory =>
      _childSubcomponentFactory$Provider.get();

  @override
  _i1.ParentThing get parentThing => _parentThing$Provider.get();
}

class ChildSubcomponent$Subcomponent implements _i1.ChildSubcomponent {
  factory ChildSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    _i1.ChildModule? childModule,
  }) => ChildSubcomponent$Subcomponent._(
    parent,
    childModule ?? _i1.ChildModule(),
  );

  ChildSubcomponent$Subcomponent._(this._parent, _i1.ChildModule childModule) {
    final childSubcomponent$childListener$Provider =
        _ChildSubcomponent$ChildListener$Provider(childModule);
    _childSubcomponent$childThing$Provider =
        _ChildSubcomponent$ChildThing$Provider(
          childSubcomponent$childListener$Provider,
          childModule,
        );
  }

  final AppComponent$Component _parent;

  late final _ChildSubcomponent$ChildThing$Provider
  _childSubcomponent$childThing$Provider;

  @override
  _i1.ChildThing get childThing => _childSubcomponent$childThing$Provider.get();
}

class _ChildSubcomponentFactory$Factory
    implements _i1.ChildSubcomponentFactory {
  const _ChildSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.ChildSubcomponent create({_i1.ChildModule? childModule}) =>
      ChildSubcomponent$Subcomponent.create(_parent, childModule: childModule);
}

class _ChildSubcomponent$ChildListener$Provider
    implements _i2.Provider<_i1.ChildListener> {
  _ChildSubcomponent$ChildListener$Provider(this._module);

  final _i1.ChildModule _module;

  late final _i1.ChildListener _singleton = _create();

  _i1.ChildListener _create() => _module.provideChildListener();

  @override
  _i1.ChildListener get() => _singleton;
}

class _ChildSubcomponent$ChildThing$Provider
    implements _i2.Provider<_i1.ChildThing> {
  _ChildSubcomponent$ChildThing$Provider(
    this._childSubcomponent$childListener$Provider,
    this._module,
  );

  final _ChildSubcomponent$ChildListener$Provider
  _childSubcomponent$childListener$Provider;

  final _i1.ChildModule _module;

  late final _i1.ChildThing _singleton = _create();

  _i1.ChildThing _create() {
    final instance = _module.provideChildThing();
    _childSubcomponent$childListener$Provider.get().onProvision(instance);
    return instance;
  }

  @override
  _i1.ChildThing get() => _singleton;
}

class _ChildSubcomponentFactory$Provider
    implements _i2.Provider<_i1.ChildSubcomponentFactory> {
  _ChildSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.ChildSubcomponentFactory _factory =
      _ChildSubcomponentFactory$Factory(_parent);

  @override
  _i1.ChildSubcomponentFactory get() => _factory;
}

class _ParentListener$Provider implements _i2.Provider<_i1.ParentListener> {
  _ParentListener$Provider(this._module);

  final _i1.ParentModule _module;

  late final _i1.ParentListener _singleton = _create();

  _i1.ParentListener _create() => _module.provideParentListener();

  @override
  _i1.ParentListener get() => _singleton;
}

class _ParentThing$Provider implements _i2.Provider<_i1.ParentThing> {
  _ParentThing$Provider(this._parentListener$Provider, this._module);

  final _ParentListener$Provider _parentListener$Provider;

  final _i1.ParentModule _module;

  late final _i1.ParentThing _singleton = _create();

  _i1.ParentThing _create() {
    final instance = _module.provideParentThing();
    _parentListener$Provider.get().onProvision(instance);
    return instance;
  }

  @override
  _i1.ParentThing get() => _singleton;
}
