// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'typedef_subcomp_factory_value_param.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    _sessionSubcomponentFactory$Provider = _SessionSubcomponentFactory$Provider(
      this,
    );
  }

  late final _SessionSubcomponentFactory$Provider
  _sessionSubcomponentFactory$Provider;

  @override
  _i1.SessionSubcomponentFactory get sessionFactory =>
      _sessionSubcomponentFactory$Provider.get();
}

class SessionSubcomponent$Subcomponent implements _i1.SessionSubcomponent {
  factory SessionSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    required _i1.GreetingBuilder greetingBuilder,
  }) => SessionSubcomponent$Subcomponent._(parent, greetingBuilder);

  SessionSubcomponent$Subcomponent._(this._parent, this.greetingBuilder) {
    _sessionSubcomponent$greetingBuilder$Provider =
        _SessionSubcomponent$GreetingBuilder$Provider(greetingBuilder);
    _sessionSubcomponent$sessionViewFactory$Provider =
        _SessionSubcomponent$SessionViewFactory$Provider(
          _sessionSubcomponent$greetingBuilder$Provider,
        );
  }

  final AppComponent$Component _parent;

  final _i1.GreetingBuilder greetingBuilder;

  late final _SessionSubcomponent$GreetingBuilder$Provider
  _sessionSubcomponent$greetingBuilder$Provider;

  late final _SessionSubcomponent$SessionViewFactory$Provider
  _sessionSubcomponent$sessionViewFactory$Provider;

  @override
  _i1.SessionViewFactory get sessionViewFactory =>
      _sessionSubcomponent$sessionViewFactory$Provider.get();
}

class _SessionSubcomponentFactory$Factory
    implements _i1.SessionSubcomponentFactory {
  const _SessionSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.SessionSubcomponent create(_i1.GreetingBuilder greetingBuilder) =>
      SessionSubcomponent$Subcomponent.create(
        _parent,
        greetingBuilder: greetingBuilder,
      );
}

class _SessionSubcomponent$GreetingBuilder$Provider
    implements _i2.Provider<_i1.GreetingBuilder> {
  const _SessionSubcomponent$GreetingBuilder$Provider(this._value);

  final _i1.GreetingBuilder _value;

  @override
  _i1.GreetingBuilder get() => _value;
}

class _SessionSubcomponent$SessionViewFactory$Factory
    implements _i1.SessionViewFactory {
  const _SessionSubcomponent$SessionViewFactory$Factory(
    this._sessionSubcomponent$greetingBuilder$Provider,
  );

  final _SessionSubcomponent$GreetingBuilder$Provider
  _sessionSubcomponent$greetingBuilder$Provider;

  @override
  _i1.SessionView create(String userId) => _i1.SessionView(
    _sessionSubcomponent$greetingBuilder$Provider.get(),
    userId,
  );
}

class _SessionSubcomponent$SessionViewFactory$Provider
    implements _i2.Provider<_i1.SessionViewFactory> {
  _SessionSubcomponent$SessionViewFactory$Provider(
    this._sessionSubcomponent$greetingBuilder$Provider,
  );

  final _SessionSubcomponent$GreetingBuilder$Provider
  _sessionSubcomponent$greetingBuilder$Provider;

  late final _i1.SessionViewFactory _factory =
      _SessionSubcomponent$SessionViewFactory$Factory(
        _sessionSubcomponent$greetingBuilder$Provider,
      );

  @override
  _i1.SessionViewFactory get() => _factory;
}

class _SessionSubcomponentFactory$Provider
    implements _i2.Provider<_i1.SessionSubcomponentFactory> {
  _SessionSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.SessionSubcomponentFactory _factory =
      _SessionSubcomponentFactory$Factory(_parent);

  @override
  _i1.SessionSubcomponentFactory get() => _factory;
}
