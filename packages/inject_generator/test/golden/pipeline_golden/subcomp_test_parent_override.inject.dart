// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'subcomp_test_parent_override.dart' as _i1;

class TestAppComponent$Component implements _i1.TestAppComponent {
  factory TestAppComponent$Component.create({
    _i1.DbModule? dbModule,
    _i1.FakeDbModule? fakeDbModule,
    _i1.SubcomponentsModule? subcomponentsModule,
  }) => TestAppComponent$Component._(
    dbModule ?? _i1.DbModule(),
    fakeDbModule ?? _i1.FakeDbModule(),
    subcomponentsModule ?? _i1.SubcomponentsModule(),
  );

  TestAppComponent$Component._(
    _i1.DbModule dbModule,
    _i1.FakeDbModule fakeDbModule,
    _i1.SubcomponentsModule subcomponentsModule,
  ) {
    _apiSubcomponentFactory$Provider = _ApiSubcomponentFactory$Provider(this);
    _database$Provider = _Database$Provider(fakeDbModule);
  }

  late final _ApiSubcomponentFactory$Provider _apiSubcomponentFactory$Provider;

  late final _Database$Provider _database$Provider;

  @override
  _i1.ApiSubcomponentFactory get apiFactory =>
      _apiSubcomponentFactory$Provider.get();

  @override
  _i1.Database get db => _database$Provider.get();
}

class ApiSubcomponent$Subcomponent implements _i1.ApiSubcomponent {
  factory ApiSubcomponent$Subcomponent.create(
    TestAppComponent$Component parent, {
    _i1.ApiModule? apiModule,
  }) => ApiSubcomponent$Subcomponent._(parent, apiModule ?? _i1.ApiModule());

  ApiSubcomponent$Subcomponent._(this._parent, _i1.ApiModule apiModule) {
    _apiSubcomponent$apiService$Provider = _ApiSubcomponent$ApiService$Provider(
      _parent._database$Provider,
      apiModule,
    );
  }

  final TestAppComponent$Component _parent;

  late final _ApiSubcomponent$ApiService$Provider
  _apiSubcomponent$apiService$Provider;

  @override
  _i1.ApiService get apiService => _apiSubcomponent$apiService$Provider.get();
}

class _ApiSubcomponentFactory$Factory implements _i1.ApiSubcomponentFactory {
  const _ApiSubcomponentFactory$Factory(this._parent);

  final TestAppComponent$Component _parent;

  @override
  _i1.ApiSubcomponent create({_i1.ApiModule? apiModule}) =>
      ApiSubcomponent$Subcomponent.create(_parent, apiModule: apiModule);
}

class _ApiSubcomponent$ApiService$Provider
    implements _i2.Provider<_i1.ApiService> {
  const _ApiSubcomponent$ApiService$Provider(
    this._database$Provider,
    this._module,
  );

  final _Database$Provider _database$Provider;

  final _i1.ApiModule _module;

  @override
  _i1.ApiService get() => _module.provideApi(_database$Provider.get());
}

class _ApiSubcomponentFactory$Provider
    implements _i2.Provider<_i1.ApiSubcomponentFactory> {
  _ApiSubcomponentFactory$Provider(this._parent);

  final TestAppComponent$Component _parent;

  late final _i1.ApiSubcomponentFactory _factory =
      _ApiSubcomponentFactory$Factory(_parent);

  @override
  _i1.ApiSubcomponentFactory get() => _factory;
}

class _Database$Provider implements _i2.Provider<_i1.Database> {
  _Database$Provider(this._module);

  final _i1.FakeDbModule _module;

  late final _i1.Database _singleton = _create();

  _i1.Database _create() => _module.provideDb();

  @override
  _i1.Database get() => _singleton;
}
