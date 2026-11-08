// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'typedef_module_binding_assisted_dep.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final greetingBuilder$Provider = _GreetingBuilder$Provider(appModule);
    final loadCount$Provider = _LoadCount$Provider(appModule);
    _optionalPageFactory$Provider = _OptionalPageFactory$Provider(
      greetingBuilder$Provider,
    );
    _pageFactory$Provider = _PageFactory$Provider(
      loadCount$Provider,
      greetingBuilder$Provider,
    );
  }

  late final _OptionalPageFactory$Provider _optionalPageFactory$Provider;

  late final _PageFactory$Provider _pageFactory$Provider;

  @override
  _i1.OptionalPageFactory get optionalPageFactory =>
      _optionalPageFactory$Provider.get();

  @override
  _i1.PageFactory get pageFactory => _pageFactory$Provider.get();
}

class _GreetingBuilder$Provider implements _i2.Provider<_i1.GreetingBuilder> {
  const _GreetingBuilder$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.GreetingBuilder get() => _module.provideGreetingBuilder();
}

class _LoadCount$Provider implements _i2.Provider<_i1.LoadCount> {
  const _LoadCount$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.LoadCount get() => _module.provideLoadCount();
}

class _OptionalPageFactory$Factory implements _i1.OptionalPageFactory {
  const _OptionalPageFactory$Factory(this._greetingBuilder$Provider);

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  @override
  _i1.OptionalPage create(String title) =>
      _i1.OptionalPage(_greetingBuilder$Provider.get(), title);
}

class _OptionalPageFactory$Provider
    implements _i2.Provider<_i1.OptionalPageFactory> {
  _OptionalPageFactory$Provider(this._greetingBuilder$Provider);

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  late final _i1.OptionalPageFactory _factory = _OptionalPageFactory$Factory(
    _greetingBuilder$Provider,
  );

  @override
  _i1.OptionalPageFactory get() => _factory;
}

class _PageFactory$Factory implements _i1.PageFactory {
  const _PageFactory$Factory(
    this._loadCount$Provider,
    this._greetingBuilder$Provider,
  );

  final _LoadCount$Provider _loadCount$Provider;

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  @override
  _i1.Page create(String title) => _i1.Page(
    _loadCount$Provider.get(),
    _greetingBuilder$Provider.get(),
    title,
  );
}

class _PageFactory$Provider implements _i2.Provider<_i1.PageFactory> {
  _PageFactory$Provider(
    this._loadCount$Provider,
    this._greetingBuilder$Provider,
  );

  final _LoadCount$Provider _loadCount$Provider;

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  late final _i1.PageFactory _factory = _PageFactory$Factory(
    _loadCount$Provider,
    _greetingBuilder$Provider,
  );

  @override
  _i1.PageFactory get() => _factory;
}
