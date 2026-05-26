// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'multi_constructor_qualifier_component.dart' as _i1;

class ProfileComponent$Component implements _i1.ProfileComponent {
  factory ProfileComponent$Component.create() => ProfileComponent$Component._();

  ProfileComponent$Component._() {
    final canvas$Provider = _Canvas$Provider();
    _configServiceDetail$Provider = _ConfigServiceDetail$Provider();
    _configServicePreview$Provider = _ConfigServicePreview$Provider();
    _profileWidgetDetail$Provider = _ProfileWidgetDetail$Provider(
      canvas$Provider,
      _configServiceDetail$Provider,
    );
    _profileWidgetPreview$Provider = _ProfileWidgetPreview$Provider(
      canvas$Provider,
      _configServicePreview$Provider,
    );
  }

  late final _ConfigServiceDetail$Provider _configServiceDetail$Provider;

  late final _ConfigServicePreview$Provider _configServicePreview$Provider;

  late final _ProfileWidgetDetail$Provider _profileWidgetDetail$Provider;

  late final _ProfileWidgetPreview$Provider _profileWidgetPreview$Provider;

  @override
  _i1.ConfigService get detailConfig => _configServiceDetail$Provider.get();

  @override
  _i1.ConfigService get previewConfig => _configServicePreview$Provider.get();

  @override
  _i1.ProfileWidget get detailWidget => _profileWidgetDetail$Provider.get();

  @override
  _i1.ProfileWidget get previewWidget => _profileWidgetPreview$Provider.get();
}

class _Canvas$Provider implements _i2.Provider<_i1.Canvas> {
  const _Canvas$Provider();

  @override
  _i1.Canvas get() => _i1.Canvas();
}

class _ConfigServiceDetail$Provider implements _i2.Provider<_i1.ConfigService> {
  _ConfigServiceDetail$Provider();

  late final _i1.ConfigService _singleton = _create();

  _i1.ConfigService _create() => _i1.ConfigService.forDetail();

  @override
  _i1.ConfigService get() => _singleton;
}

class _ConfigServicePreview$Provider
    implements _i2.Provider<_i1.ConfigService> {
  _ConfigServicePreview$Provider();

  late final _i1.ConfigService _singleton = _create();

  _i1.ConfigService _create() => _i1.ConfigService.forPreview();

  @override
  _i1.ConfigService get() => _singleton;
}

class _ProfileWidgetDetail$Provider implements _i2.Provider<_i1.ProfileWidget> {
  const _ProfileWidgetDetail$Provider(
    this._canvas$Provider,
    this._configServiceDetail$Provider,
  );

  final _Canvas$Provider _canvas$Provider;

  final _ConfigServiceDetail$Provider _configServiceDetail$Provider;

  @override
  _i1.ProfileWidget get() => _i1.ProfileWidget.detail(
    _canvas$Provider.get(),
    _configServiceDetail$Provider.get(),
  );
}

class _ProfileWidgetPreview$Provider
    implements _i2.Provider<_i1.ProfileWidget> {
  const _ProfileWidgetPreview$Provider(
    this._canvas$Provider,
    this._configServicePreview$Provider,
  );

  final _Canvas$Provider _canvas$Provider;

  final _ConfigServicePreview$Provider _configServicePreview$Provider;

  @override
  _i1.ProfileWidget get() => _i1.ProfileWidget.preview(
    _canvas$Provider.get(),
    _configServicePreview$Provider.get(),
  );
}
