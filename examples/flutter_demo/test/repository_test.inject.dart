// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter_demo/src/data/repositories/counter_repository.dart'
    as _i3;
import 'package:flutter_demo/src/data/services/database.dart' as _i2;
import 'package:inject_annotation/inject_annotation.dart' as _i4;

import 'repository_test.dart' as _i1;

class TestRepositoryComponent$Component implements _i1.TestRepositoryComponent {
  factory TestRepositoryComponent$Component.create({
    _i2.DatabaseModule? databaseModule,
    _i1.TestDatabaseModule? testDatabaseModule,
  }) => TestRepositoryComponent$Component._(
    databaseModule ?? _i2.DatabaseModule(),
    testDatabaseModule ?? _i1.TestDatabaseModule(),
  );

  TestRepositoryComponent$Component._(
    _i2.DatabaseModule databaseModule,
    _i1.TestDatabaseModule testDatabaseModule,
  ) {
    final stringDatabasePath$Provider = _StringDatabasePath$Provider(
      databaseModule,
    );
    final stringDatabaseName$Provider = _StringDatabaseName$Provider(
      databaseModule,
    );
    final database$Provider = _Database$Provider(
      stringDatabasePath$Provider,
      stringDatabaseName$Provider,
      testDatabaseModule,
    );
    _counterRepository$Provider = _CounterRepository$Provider(
      database$Provider,
    );
  }

  late final _CounterRepository$Provider _counterRepository$Provider;

  @override
  _i3.CounterRepository get counterRepository =>
      _counterRepository$Provider.get();
}

class _CounterRepository$Provider
    implements _i4.Provider<_i3.CounterRepository> {
  _CounterRepository$Provider(this._database$Provider);

  final _Database$Provider _database$Provider;

  late final _i3.CounterRepository _singleton = _create();

  _i3.CounterRepository _create() =>
      _i3.CounterRepository(database: _database$Provider.get());

  @override
  _i3.CounterRepository get() => _singleton;
}

class _Database$Provider implements _i4.Provider<_i2.Database> {
  _Database$Provider(
    this._stringDatabasePath$Provider,
    this._stringDatabaseName$Provider,
    this._module,
  );

  final _StringDatabasePath$Provider _stringDatabasePath$Provider;

  final _StringDatabaseName$Provider _stringDatabaseName$Provider;

  final _i1.TestDatabaseModule _module;

  late final _i2.Database _singleton = _create();

  _i2.Database _create() => _module.provideDatabase(
    _stringDatabasePath$Provider.get(),
    _stringDatabaseName$Provider.get(),
  );

  @override
  _i2.Database get() => _singleton;
}

class _StringDatabaseName$Provider implements _i4.Provider<String> {
  const _StringDatabaseName$Provider(this._module);

  final _i2.DatabaseModule _module;

  @override
  String get() => _module.provideDatabaseName();
}

class _StringDatabasePath$Provider implements _i4.Provider<String> {
  const _StringDatabasePath$Provider(this._module);

  final _i2.DatabaseModule _module;

  @override
  String get() => _module.provideDatabasePath();
}
