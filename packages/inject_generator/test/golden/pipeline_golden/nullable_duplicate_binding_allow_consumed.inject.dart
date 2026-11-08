// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nullable_duplicate_binding_allow_consumed.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final service$Provider = _Service$Provider(appModule);
    final serviceNullable$Provider = _ServiceNullable$Provider(appModule);
    _consumer$Provider = _Consumer$Provider(
      service$Provider,
      serviceNullable$Provider,
    );
    _pageFactory$Provider = _PageFactory$Provider(
      service$Provider,
      serviceNullable$Provider,
    );
  }

  late final _Consumer$Provider _consumer$Provider;

  late final _PageFactory$Provider _pageFactory$Provider;

  @override
  _i1.Consumer get consumer => _consumer$Provider.get();

  @override
  _i1.PageFactory get pageFactory => _pageFactory$Provider.get();
}

class _Consumer$Provider implements _i2.Provider<_i1.Consumer> {
  const _Consumer$Provider(
    this._service$Provider,
    this._serviceNullable$Provider,
  );

  final _Service$Provider _service$Provider;

  final _ServiceNullable$Provider _serviceNullable$Provider;

  @override
  _i1.Consumer get() =>
      _i1.Consumer(_service$Provider.get(), _serviceNullable$Provider.get());
}

class _PageFactory$Factory implements _i1.PageFactory {
  const _PageFactory$Factory(
    this._service$Provider,
    this._serviceNullable$Provider,
  );

  final _Service$Provider _service$Provider;

  final _ServiceNullable$Provider _serviceNullable$Provider;

  @override
  _i1.Page create(int id) =>
      _i1.Page(_service$Provider.get(), _serviceNullable$Provider.get(), id);
}

class _PageFactory$Provider implements _i2.Provider<_i1.PageFactory> {
  _PageFactory$Provider(this._service$Provider, this._serviceNullable$Provider);

  final _Service$Provider _service$Provider;

  final _ServiceNullable$Provider _serviceNullable$Provider;

  late final _i1.PageFactory _factory = _PageFactory$Factory(
    _service$Provider,
    _serviceNullable$Provider,
  );

  @override
  _i1.PageFactory get() => _factory;
}

class _Service$Provider implements _i2.Provider<_i1.Service> {
  const _Service$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Service get() => _module.provideService();
}

class _ServiceNullable$Provider implements _i2.Provider<_i1.Service?> {
  const _ServiceNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Service? get() => _module.provideOptionalService();
}
