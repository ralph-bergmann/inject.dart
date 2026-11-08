// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'typedef_provider_synthesized_assisted_dep.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final clock$Provider = _Clock$Provider();
    final greetingBuilder$Provider = _GreetingBuilder$Provider(clock$Provider);
    _pageFactory$Provider = _PageFactory$Provider(greetingBuilder$Provider);
  }

  late final _PageFactory$Provider _pageFactory$Provider;

  @override
  _i1.PageFactory get pageFactory => _pageFactory$Provider.get();
}

class _Clock$Provider implements _i2.Provider<_i1.Clock> {
  const _Clock$Provider();

  @override
  _i1.Clock get() => _i1.Clock();
}

class _GreetingBuilder$Provider implements _i2.Provider<_i1.GreetingBuilder> {
  const _GreetingBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.GreetingBuilder get() =>
      (String name) => _i1.Greeting(name, _clock$Provider.get());
}

class _PageFactory$Factory implements _i1.PageFactory {
  const _PageFactory$Factory(this._greetingBuilder$Provider);

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  @override
  _i1.Page create(String title) =>
      _i1.Page(_greetingBuilder$Provider.get(), title);
}

class _PageFactory$Provider implements _i2.Provider<_i1.PageFactory> {
  _PageFactory$Provider(this._greetingBuilder$Provider);

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  late final _i1.PageFactory _factory = _PageFactory$Factory(
    _greetingBuilder$Provider,
  );

  @override
  _i1.PageFactory get() => _factory;
}
