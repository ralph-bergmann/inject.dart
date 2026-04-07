// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'synthesized_multiple_assisted.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final logger$Provider = _Logger$Provider();
    _greetingFactory$Provider = _GreetingFactory$Provider(logger$Provider);
  }

  late final _GreetingFactory$Provider _greetingFactory$Provider;

  @override
  _i1.GreetingFactory get greetingFactory => _greetingFactory$Provider.get();
}

class _GreetingFactory$Factory implements _i1.GreetingFactory {
  const _GreetingFactory$Factory(this._logger$Provider);

  final _Logger$Provider _logger$Provider;

  @override
  _i1.Greeting create(String name, int count) =>
      _i1.Greeting(_logger$Provider.get(), name, count);
}

class _GreetingFactory$Provider implements _i2.Provider<_i1.GreetingFactory> {
  _GreetingFactory$Provider(this._logger$Provider);

  final _Logger$Provider _logger$Provider;

  late final _i1.GreetingFactory _factory = _GreetingFactory$Factory(
    _logger$Provider,
  );

  @override
  _i1.GreetingFactory get() => _factory;
}

class _Logger$Provider implements _i2.Provider<_i1.Logger> {
  const _Logger$Provider();

  @override
  _i1.Logger get() => _i1.Logger();
}
