// ignore_for_file: implementation_imports
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter_demo/src/data/repositories/counter_repository.dart'
    as _i2;
import 'package:flutter_demo/src/data/services/database.dart' as _i4;
import 'package:inject_annotation/inject_annotation.dart' as _i3;

import 'repository_test.dart' as _i1;

class TestComponent$Component implements _i1.TestComponent {
  factory TestComponent$Component.create({_i1.TestModule? testModule}) =>
      TestComponent$Component._(testModule ?? _i1.TestModule());

  TestComponent$Component._(_i1.TestModule testModule) {
    final database$Provider = _Database$Provider(testModule);
    _counterRepository$Provider = _CounterRepository$Provider(
      database$Provider,
    );
  }

  late final _CounterRepository$Provider _counterRepository$Provider;

  @override
  _i2.CounterRepository get counterRepository =>
      _counterRepository$Provider.get();
}

class _Database$Provider implements _i3.Provider<_i4.Database> {
  _Database$Provider(this._module);

  final _i1.TestModule _module;

  _i4.Database? _singleton;

  @override
  _i4.Database get() => _singleton ??= _module.provideDatabase();
}

class _CounterRepository$Provider
    implements _i3.Provider<_i2.CounterRepository> {
  _CounterRepository$Provider(this._database$Provider);

  final _Database$Provider _database$Provider;

  _i2.CounterRepository? _singleton;

  @override
  _i2.CounterRepository get() =>
      _singleton ??= _i2.CounterRepository(database: _database$Provider.get());
}
