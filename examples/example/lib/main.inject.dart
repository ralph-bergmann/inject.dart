// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter/src/foundation/key.dart' as _i3;
import 'package:flutter/src/widgets/framework.dart' as _i5;
import 'package:inject_annotation/inject_annotation.dart' as _i2;
import 'package:inject_flutter/src/view_model_factory.dart' as _i4;

import 'main.dart' as _i1;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({_i1.AppModule? appModule}) =>
      MainComponent$Component._(appModule ?? _i1.AppModule());

  MainComponent$Component._(_i1.AppModule appModule) {
    final database$Provider = _Database$Provider(appModule);
    final counterRepository$Provider = _CounterRepository$Provider(
      database$Provider,
    );
    final counterViewModel$Provider = _CounterViewModel$Provider(
      counterRepository$Provider,
    );
    final viewModelFactoryOfCounterViewModel$Provider =
        _ViewModelFactoryOfCounterViewModel$Provider(counterViewModel$Provider);
    final homePageFactory$Provider = _HomePageFactory$Provider(
      viewModelFactoryOfCounterViewModel$Provider,
    );
    _myAppFactory$Provider = _MyAppFactory$Provider(homePageFactory$Provider);
  }

  late final _MyAppFactory$Provider _myAppFactory$Provider;

  @override
  _i1.MyAppFactory get myAppFactory => _myAppFactory$Provider.get();
}

class _CounterRepository$Provider
    implements _i2.Provider<_i1.CounterRepository> {
  _CounterRepository$Provider(this._database$Provider);

  final _Database$Provider _database$Provider;

  late final _i1.CounterRepository _singleton = _create();

  _i1.CounterRepository _create() =>
      _i1.CounterRepository(database: _database$Provider.get());

  @override
  _i1.CounterRepository get() => _singleton;
}

class _CounterViewModel$Provider implements _i2.Provider<_i1.CounterViewModel> {
  const _CounterViewModel$Provider(this._counterRepository$Provider);

  final _CounterRepository$Provider _counterRepository$Provider;

  @override
  _i1.CounterViewModel get() =>
      _i1.CounterViewModel(repository: _counterRepository$Provider.get());
}

class _Database$Provider implements _i2.Provider<_i1.Database> {
  _Database$Provider(this._module);

  final _i1.AppModule _module;

  late final _i1.Database _singleton = _create();

  _i1.Database _create() => _module.provideDatabase();

  @override
  _i1.Database get() => _singleton;
}

class _HomePageFactory$Factory implements _i1.HomePageFactory {
  const _HomePageFactory$Factory(
    this._viewModelFactoryOfCounterViewModel$Provider,
  );

  final _ViewModelFactoryOfCounterViewModel$Provider
  _viewModelFactoryOfCounterViewModel$Provider;

  @override
  _i1.HomePage create({_i3.Key? key, required String title}) => _i1.HomePage(
    key: key,
    title: title,
    viewModelFactory: _viewModelFactoryOfCounterViewModel$Provider.get(),
  );
}

class _HomePageFactory$Provider implements _i2.Provider<_i1.HomePageFactory> {
  _HomePageFactory$Provider(this._viewModelFactoryOfCounterViewModel$Provider);

  final _ViewModelFactoryOfCounterViewModel$Provider
  _viewModelFactoryOfCounterViewModel$Provider;

  late final _i1.HomePageFactory _factory = _HomePageFactory$Factory(
    _viewModelFactoryOfCounterViewModel$Provider,
  );

  @override
  _i1.HomePageFactory get() => _factory;
}

class _MyAppFactory$Factory implements _i1.MyAppFactory {
  const _MyAppFactory$Factory(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  @override
  _i1.MyApp create({_i3.Key? key}) =>
      _i1.MyApp(key: key, homePageFactory: _homePageFactory$Provider.get());
}

class _MyAppFactory$Provider implements _i2.Provider<_i1.MyAppFactory> {
  _MyAppFactory$Provider(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  late final _i1.MyAppFactory _factory = _MyAppFactory$Factory(
    _homePageFactory$Provider,
  );

  @override
  _i1.MyAppFactory get() => _factory;
}

class _ViewModelFactoryOfCounterViewModel$Provider
    implements _i2.Provider<_i4.ViewModelFactory<_i1.CounterViewModel>> {
  const _ViewModelFactoryOfCounterViewModel$Provider(
    this._counterViewModel$Provider,
  );

  final _CounterViewModel$Provider _counterViewModel$Provider;

  @override
  _i4.ViewModelFactory<_i1.CounterViewModel> get() =>
      ({
        required _i4.ViewModelWidgetBuilder<_i1.CounterViewModel> builder,
        _i5.Widget? child,
        _i4.ViewModelErrorBuilder? error,
        _i4.ViewModelInitializer<_i1.CounterViewModel>? init,
        _i3.Key? key,
        _i5.Widget? loading,
      }) => _i4.ViewModelBuilder<_i1.CounterViewModel>(
        key: key,
        viewModelProvider: _counterViewModel$Provider,
        init: init,
        loading: loading,
        error: error,
        builder: builder,
        child: child,
      );
}
