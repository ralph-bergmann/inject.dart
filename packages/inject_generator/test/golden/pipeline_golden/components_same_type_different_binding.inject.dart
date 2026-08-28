// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'components_same_type_different_binding.dart' as _i1;

class FeatureComponent$Component implements _i1.FeatureComponent {
  factory FeatureComponent$Component.create({
    required _i1.DatabaseModule databaseModule,
  }) => FeatureComponent$Component._(databaseModule);

  FeatureComponent$Component._(_i1.DatabaseModule databaseModule) {
    _featureComponent$database$Provider = _FeatureComponent$Database$Provider(
      databaseModule,
    );
  }

  late final _FeatureComponent$Database$Provider
  _featureComponent$database$Provider;

  @override
  _i1.Database get database => _featureComponent$database$Provider.get();
}

class RootComponent$Component implements _i1.RootComponent {
  factory RootComponent$Component.create() => RootComponent$Component._();

  RootComponent$Component._() {
    _rootComponent$database$Provider = _RootComponent$Database$Provider();
  }

  late final _RootComponent$Database$Provider _rootComponent$database$Provider;

  @override
  _i1.Database get database => _rootComponent$database$Provider.get();
}

class _FeatureComponent$Database$Provider
    implements _i2.Provider<_i1.Database> {
  const _FeatureComponent$Database$Provider(this._module);

  final _i1.DatabaseModule _module;

  @override
  _i1.Database get() => _module.provideDatabase();
}

class _RootComponent$Database$Provider implements _i2.Provider<_i1.Database> {
  const _RootComponent$Database$Provider();

  @override
  _i1.Database get() => _i1.Database();
}
