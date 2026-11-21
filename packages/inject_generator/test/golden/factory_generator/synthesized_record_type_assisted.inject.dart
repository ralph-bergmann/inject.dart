// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_record_type_assisted.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final logger$Provider = _Logger$Provider();
    _hostFactory$Provider = _HostFactory$Provider(logger$Provider);
  }

  late final _HostFactory$Provider _hostFactory$Provider;

  @override
  _i1.HostFactory get hostFactory => _hostFactory$Provider.get();
}

class _HostFactory$Factory implements _i1.HostFactory {
  const _HostFactory$Factory(this._logger$Provider);

  final _Logger$Provider _logger$Provider;

  @override
  _i1.Host create(
    (_i1.Slots, _i1.Child) pair,
    ({_i1.Child child, _i1.Slots slots}) named,
    (List<_i1.Slots>, {(_i1.Child, _i1.Logger)? nested})? mixed,
    (_i1.Slots,) single,
  ) => _i1.Host(_logger$Provider.get(), pair, named, mixed, single);
}

class _HostFactory$Provider implements _i2.Provider<_i1.HostFactory> {
  _HostFactory$Provider(this._logger$Provider);

  final _Logger$Provider _logger$Provider;

  late final _i1.HostFactory _factory = _HostFactory$Factory(_logger$Provider);

  @override
  _i1.HostFactory get() => _factory;
}

class _Logger$Provider implements _i2.Provider<_i1.Logger> {
  const _Logger$Provider();

  @override
  _i1.Logger get() => _i1.Logger();
}
