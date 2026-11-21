// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_function_type_assisted.dart' as _i1;

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
    _i1.Child Function(_i1.Slots, [_i1.Logger?]) builder,
    void Function(List<_i1.Slots>, {required _i1.Child child, int? index})?
    onTap,
    _i1.Child Function<T extends _i1.Slots>(T) mapper,
  ) => _i1.Host(_logger$Provider.get(), builder, onTap, mapper);
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
