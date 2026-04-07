// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'inject_named_params.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final database$Provider = _Database$Provider();
    _counterRepository$Provider = _CounterRepository$Provider(
      database$Provider,
    );
  }

  late final _CounterRepository$Provider _counterRepository$Provider;

  @override
  _i1.CounterRepository get counterRepository =>
      _counterRepository$Provider.get();
}

class _CounterRepository$Provider
    implements _i2.Provider<_i1.CounterRepository> {
  const _CounterRepository$Provider(this._database$Provider);

  final _Database$Provider _database$Provider;

  @override
  _i1.CounterRepository get() =>
      _i1.CounterRepository(database: _database$Provider.get());
}

class _Database$Provider implements _i2.Provider<_i1.Database> {
  const _Database$Provider();

  @override
  _i1.Database get() => _i1.Database();
}
