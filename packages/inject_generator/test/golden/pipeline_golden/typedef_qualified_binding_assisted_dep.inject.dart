// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'typedef_qualified_binding_assisted_dep.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final clock$Provider = _Clock$Provider();
    final greetingBuilder$Provider = _GreetingBuilder$Provider(clock$Provider);
    final greetingBuilderPrimary$Provider = _GreetingBuilderPrimary$Provider(
      appModule,
    );
    _qualifiedPageFactory$Provider = _QualifiedPageFactory$Provider(
      greetingBuilderPrimary$Provider,
    );
    _unqualifiedPageFactory$Provider = _UnqualifiedPageFactory$Provider(
      greetingBuilder$Provider,
    );
  }

  late final _QualifiedPageFactory$Provider _qualifiedPageFactory$Provider;

  late final _UnqualifiedPageFactory$Provider _unqualifiedPageFactory$Provider;

  @override
  _i1.QualifiedPageFactory get qualifiedPageFactory =>
      _qualifiedPageFactory$Provider.get();

  @override
  _i1.UnqualifiedPageFactory get unqualifiedPageFactory =>
      _unqualifiedPageFactory$Provider.get();
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

class _GreetingBuilderPrimary$Provider
    implements _i2.Provider<_i1.GreetingBuilder> {
  const _GreetingBuilderPrimary$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.GreetingBuilder get() => _module.providePrimaryGreetingBuilder();
}

class _QualifiedPageFactory$Factory implements _i1.QualifiedPageFactory {
  const _QualifiedPageFactory$Factory(this._greetingBuilderPrimary$Provider);

  final _GreetingBuilderPrimary$Provider _greetingBuilderPrimary$Provider;

  @override
  _i1.QualifiedPage create(String title) =>
      _i1.QualifiedPage(_greetingBuilderPrimary$Provider.get(), title);
}

class _QualifiedPageFactory$Provider
    implements _i2.Provider<_i1.QualifiedPageFactory> {
  _QualifiedPageFactory$Provider(this._greetingBuilderPrimary$Provider);

  final _GreetingBuilderPrimary$Provider _greetingBuilderPrimary$Provider;

  late final _i1.QualifiedPageFactory _factory = _QualifiedPageFactory$Factory(
    _greetingBuilderPrimary$Provider,
  );

  @override
  _i1.QualifiedPageFactory get() => _factory;
}

class _UnqualifiedPageFactory$Factory implements _i1.UnqualifiedPageFactory {
  const _UnqualifiedPageFactory$Factory(this._greetingBuilder$Provider);

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  @override
  _i1.UnqualifiedPage create(String title) =>
      _i1.UnqualifiedPage(_greetingBuilder$Provider.get(), title);
}

class _UnqualifiedPageFactory$Provider
    implements _i2.Provider<_i1.UnqualifiedPageFactory> {
  _UnqualifiedPageFactory$Provider(this._greetingBuilder$Provider);

  final _GreetingBuilder$Provider _greetingBuilder$Provider;

  late final _i1.UnqualifiedPageFactory _factory =
      _UnqualifiedPageFactory$Factory(_greetingBuilder$Provider);

  @override
  _i1.UnqualifiedPageFactory get() => _factory;
}
