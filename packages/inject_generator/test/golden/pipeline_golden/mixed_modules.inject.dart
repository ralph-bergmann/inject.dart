// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'mixed_modules.dart' as _i1;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({
    required _i1.ModuleA moduleA,
    _i1.ModuleB? moduleB,
    _i1.ModuleC? moduleC,
    _i1.ModuleD? moduleD,
  }) => MainComponent$Component._(
    moduleA,
    moduleB ?? _i1.ModuleB(),
    moduleC ?? _i1.ModuleC(),
    moduleD ?? _i1.ModuleD(),
  );

  MainComponent$Component._(
    _i1.ModuleA moduleA,
    _i1.ModuleB moduleB,
    _i1.ModuleC moduleC,
    _i1.ModuleD moduleD,
  ) {
    _serviceA$Provider = _ServiceA$Provider(moduleA);
    _serviceB$Provider = _ServiceB$Provider(moduleB);
    _serviceC$Provider = _ServiceC$Provider(moduleC);
    _serviceD$Provider = _ServiceD$Provider(moduleD);
  }

  late final _ServiceA$Provider _serviceA$Provider;

  late final _ServiceB$Provider _serviceB$Provider;

  late final _ServiceC$Provider _serviceC$Provider;

  late final _ServiceD$Provider _serviceD$Provider;

  @override
  _i1.ServiceA get serviceA => _serviceA$Provider.get();

  @override
  _i1.ServiceB get serviceB => _serviceB$Provider.get();

  @override
  _i1.ServiceC get serviceC => _serviceC$Provider.get();

  @override
  _i1.ServiceD get serviceD => _serviceD$Provider.get();
}

class _ServiceA$Provider implements _i2.Provider<_i1.ServiceA> {
  const _ServiceA$Provider(this._module);

  final _i1.ModuleA _module;

  @override
  _i1.ServiceA get() => _module.provideServiceA();
}

class _ServiceB$Provider implements _i2.Provider<_i1.ServiceB> {
  const _ServiceB$Provider(this._module);

  final _i1.ModuleB _module;

  @override
  _i1.ServiceB get() => _module.provideServiceB();
}

class _ServiceC$Provider implements _i2.Provider<_i1.ServiceC> {
  const _ServiceC$Provider(this._module);

  final _i1.ModuleC _module;

  @override
  _i1.ServiceC get() => _module.provideServiceC();
}

class _ServiceD$Provider implements _i2.Provider<_i1.ServiceD> {
  const _ServiceD$Provider(this._module);

  final _i1.ModuleD _module;

  @override
  _i1.ServiceD get() => _module.provideServiceD();
}
