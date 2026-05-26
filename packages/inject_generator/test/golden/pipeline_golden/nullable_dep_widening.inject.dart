// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nullable_dep_widening.dart' as _i1;

class Garage$Component implements _i1.Garage {
  factory Garage$Component.create() => Garage$Component._();

  Garage$Component._() {
    final engine$Provider = _Engine$Provider();
    _car$Provider = _Car$Provider(engine$Provider);
  }

  late final _Car$Provider _car$Provider;

  @override
  _i1.Car get car => _car$Provider.get();
}

class _Car$Provider implements _i2.Provider<_i1.Car> {
  const _Car$Provider(this._engine$Provider);

  final _Engine$Provider _engine$Provider;

  @override
  _i1.Car get() => _i1.Car(_engine$Provider.get());
}

class _Engine$Provider implements _i2.Provider<_i1.Engine> {
  const _Engine$Provider();

  @override
  _i1.Engine get() => _i1.Engine();
}
