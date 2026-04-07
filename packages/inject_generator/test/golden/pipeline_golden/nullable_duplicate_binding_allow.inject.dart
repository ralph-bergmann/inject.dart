// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nullable_duplicate_binding_allow.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final serviceImpl$Provider = _ServiceImpl$Provider();
    _service$Provider = _Service$Provider(serviceImpl$Provider, appModule);
    _serviceNullable$Provider = _ServiceNullable$Provider(
      serviceImpl$Provider,
      appModule,
    );
  }

  late final _Service$Provider _service$Provider;

  late final _ServiceNullable$Provider _serviceNullable$Provider;

  @override
  _i1.Service get service => _service$Provider.get();

  @override
  _i1.Service? get optionalService => _serviceNullable$Provider.get();
}

class _Service$Provider implements _i2.Provider<_i1.Service> {
  const _Service$Provider(this._serviceImpl$Provider, this._module);

  final _ServiceImpl$Provider _serviceImpl$Provider;

  final _i1.AppModule _module;

  @override
  _i1.Service get() => _module.provideService(_serviceImpl$Provider.get());
}

class _ServiceImpl$Provider implements _i2.Provider<_i1.ServiceImpl> {
  const _ServiceImpl$Provider();

  @override
  _i1.ServiceImpl get() => _i1.ServiceImpl();
}

class _ServiceNullable$Provider implements _i2.Provider<_i1.Service?> {
  const _ServiceNullable$Provider(this._serviceImpl$Provider, this._module);

  final _ServiceImpl$Provider _serviceImpl$Provider;

  final _i1.AppModule _module;

  @override
  _i1.Service? get() =>
      _module.provideOptionalService(_serviceImpl$Provider.get());
}
