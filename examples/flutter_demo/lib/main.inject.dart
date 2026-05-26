// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i7;

import 'package:flutter/src/foundation/key.dart' as _i11;
import 'package:flutter/src/widgets/framework.dart' as _i14;
import 'package:inject_annotation/inject_annotation.dart' as _i8;
import 'package:inject_annotation/src/api/provider.dart' as _i4;
import 'package:inject_flutter/src/view_model_factory.dart' as _i13;

import 'main.dart' as _i1;
import 'src/app_module.dart' as _i2;
import 'src/data/repositories/counter_repository.dart' as _i5;
import 'src/data/services/database.dart' as _i3;
import 'src/domain/use_cases/increment_counter_use_case.dart' as _i12;
import 'src/features/app/my_app.dart' as _i6;
import 'src/features/home/counter_view_model.dart' as _i9;
import 'src/features/home/home_page.dart' as _i10;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({
    _i2.AppModule? appModule,
    _i3.DatabaseModule? databaseModule,
  }) => MainComponent$Component._(
    appModule ?? _i2.AppModule(),
    databaseModule ?? _i3.DatabaseModule(),
  );

  MainComponent$Component._(
    _i2.AppModule appModule,
    _i3.DatabaseModule databaseModule,
  ) {
    final appInfo$Provider = _AppInfo$Provider(appModule);
    final stringDatabasePath$Provider = _StringDatabasePath$Provider(
      databaseModule,
    );
    final stringDatabaseName$Provider = _StringDatabaseName$Provider(
      databaseModule,
    );
    final database$Provider = _Database$Provider(
      stringDatabasePath$Provider,
      stringDatabaseName$Provider,
      databaseModule,
    );
    _counterRepository$Provider = _CounterRepository$Provider(
      database$Provider,
    );
    final incrementCounterUseCase$Provider = _IncrementCounterUseCase$Provider(
      _counterRepository$Provider,
    );
    final futureOfInt$Provider = _FutureOfInt$Provider(appModule);
    _creationLogListener$Provider = _CreationLogListener$Provider(appModule);
    final counterViewModel$Provider = _CounterViewModel$Provider(
      incrementCounterUseCase$Provider,
      futureOfInt$Provider,
      _creationLogListener$Provider,
    );
    final viewModelFactoryOfCounterViewModel$Provider =
        _ViewModelFactoryOfCounterViewModel$Provider(counterViewModel$Provider);
    final homePageFactory$Provider = _HomePageFactory$Provider(
      viewModelFactoryOfCounterViewModel$Provider,
    );
    _myAppFactory$Provider = _MyAppFactory$Provider(homePageFactory$Provider);
    _stringWelcome$Provider = _StringWelcome$Provider(
      appInfo$Provider,
      appModule,
    );
  }

  late final _CounterRepository$Provider _counterRepository$Provider;

  late final _CreationLogListener$Provider _creationLogListener$Provider;

  late final _MyAppFactory$Provider _myAppFactory$Provider;

  late final _StringWelcome$Provider _stringWelcome$Provider;

  @override
  _i4.Provider<_i5.CounterRepository> get counterRepositoryProvider =>
      _counterRepository$Provider;

  @override
  _i2.CreationLogListener get creationLogListener =>
      _creationLogListener$Provider.get();

  @override
  _i6.MyAppFactory get myAppFactory => _myAppFactory$Provider.get();

  @override
  _i7.Future<String> get welcomeMessage => _stringWelcome$Provider.get();
}

class _AppInfo$Provider implements _i8.Provider<_i7.Future<_i2.AppInfo>> {
  _AppInfo$Provider(this._module);

  final _i2.AppModule _module;

  _i7.Future<_i2.AppInfo>? _singletonFuture;

  _i7.Future<_i2.AppInfo> _create() => _module.provideAppInfo();

  @override
  _i7.Future<_i2.AppInfo> get() => _singletonFuture ??= _create();
}

class _CounterRepository$Provider
    implements _i8.Provider<_i5.CounterRepository> {
  _CounterRepository$Provider(this._database$Provider);

  final _Database$Provider _database$Provider;

  late final _i5.CounterRepository _singleton = _create();

  _i5.CounterRepository _create() =>
      _i5.CounterRepository(database: _database$Provider.get());

  @override
  _i5.CounterRepository get() => _singleton;
}

class _CounterViewModel$Provider implements _i8.Provider<_i9.CounterViewModel> {
  const _CounterViewModel$Provider(
    this._incrementCounterUseCase$Provider,
    this._futureOfInt$Provider,
    this._creationLogListener$Provider,
  );

  final _IncrementCounterUseCase$Provider _incrementCounterUseCase$Provider;

  final _FutureOfInt$Provider _futureOfInt$Provider;

  final _CreationLogListener$Provider _creationLogListener$Provider;

  @override
  _i9.CounterViewModel get() {
    final instance = _i9.CounterViewModel(
      incrementUseCase: _incrementCounterUseCase$Provider.get(),
      initialCount: _futureOfInt$Provider.get(),
    );
    _creationLogListener$Provider.get().onProvision(instance);
    return instance;
  }
}

class _CreationLogListener$Provider
    implements _i8.Provider<_i2.CreationLogListener> {
  _CreationLogListener$Provider(this._module);

  final _i2.AppModule _module;

  late final _i2.CreationLogListener _singleton = _create();

  _i2.CreationLogListener _create() => _module.provideCreationLogListener();

  @override
  _i2.CreationLogListener get() => _singleton;
}

class _Database$Provider implements _i8.Provider<_i3.Database> {
  _Database$Provider(
    this._stringDatabasePath$Provider,
    this._stringDatabaseName$Provider,
    this._module,
  );

  final _StringDatabasePath$Provider _stringDatabasePath$Provider;

  final _StringDatabaseName$Provider _stringDatabaseName$Provider;

  final _i3.DatabaseModule _module;

  late final _i3.Database _singleton = _create();

  _i3.Database _create() => _module.provideDatabase(
    _stringDatabasePath$Provider.get(),
    _stringDatabaseName$Provider.get(),
  );

  @override
  _i3.Database get() => _singleton;
}

class _FutureOfInt$Provider implements _i8.Provider<_i7.Future<int>> {
  _FutureOfInt$Provider(this._module);

  final _i2.AppModule _module;

  late final _i7.Future<int> _singleton = _create();

  _i7.Future<int> _create() => _module.provideInitialCount();

  @override
  _i7.Future<int> get() => _singleton;
}

class _HomePageFactory$Factory implements _i10.HomePageFactory {
  const _HomePageFactory$Factory(
    this._viewModelFactoryOfCounterViewModel$Provider,
  );

  final _ViewModelFactoryOfCounterViewModel$Provider
  _viewModelFactoryOfCounterViewModel$Provider;

  @override
  _i10.HomePage create({_i11.Key? key, required String title}) => _i10.HomePage(
    key: key,
    title: title,
    viewModelFactory: _viewModelFactoryOfCounterViewModel$Provider.get(),
  );
}

class _HomePageFactory$Provider implements _i8.Provider<_i10.HomePageFactory> {
  _HomePageFactory$Provider(this._viewModelFactoryOfCounterViewModel$Provider);

  final _ViewModelFactoryOfCounterViewModel$Provider
  _viewModelFactoryOfCounterViewModel$Provider;

  late final _i10.HomePageFactory _factory = _HomePageFactory$Factory(
    _viewModelFactoryOfCounterViewModel$Provider,
  );

  @override
  _i10.HomePageFactory get() => _factory;
}

class _IncrementCounterUseCase$Provider
    implements _i8.Provider<_i12.IncrementCounterUseCase> {
  _IncrementCounterUseCase$Provider(this._counterRepository$Provider);

  final _CounterRepository$Provider _counterRepository$Provider;

  late final _i12.IncrementCounterUseCase _singleton = _create();

  _i12.IncrementCounterUseCase _create() => _i12.IncrementCounterUseCase(
    repository: _counterRepository$Provider.get(),
  );

  @override
  _i12.IncrementCounterUseCase get() => _singleton;
}

class _MyAppFactory$Factory implements _i6.MyAppFactory {
  const _MyAppFactory$Factory(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  @override
  _i6.MyApp create({_i11.Key? key}) =>
      _i6.MyApp(key: key, homePageFactory: _homePageFactory$Provider.get());
}

class _MyAppFactory$Provider implements _i8.Provider<_i6.MyAppFactory> {
  _MyAppFactory$Provider(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  late final _i6.MyAppFactory _factory = _MyAppFactory$Factory(
    _homePageFactory$Provider,
  );

  @override
  _i6.MyAppFactory get() => _factory;
}

class _StringDatabaseName$Provider implements _i8.Provider<String> {
  const _StringDatabaseName$Provider(this._module);

  final _i3.DatabaseModule _module;

  @override
  String get() => _module.provideDatabaseName();
}

class _StringDatabasePath$Provider implements _i8.Provider<String> {
  const _StringDatabasePath$Provider(this._module);

  final _i3.DatabaseModule _module;

  @override
  String get() => _module.provideDatabasePath();
}

class _StringWelcome$Provider implements _i8.Provider<_i7.Future<String>> {
  _StringWelcome$Provider(this._appInfo$Provider, this._module);

  final _AppInfo$Provider _appInfo$Provider;

  final _i2.AppModule _module;

  _i7.Future<String>? _singletonFuture;

  _i7.Future<String> _create() async =>
      _module.provideWelcomeMessage(await _appInfo$Provider.get());

  @override
  _i7.Future<String> get() => _singletonFuture ??= _create();
}

class _ViewModelFactoryOfCounterViewModel$Provider
    implements _i8.Provider<_i13.ViewModelFactory<_i9.CounterViewModel>> {
  const _ViewModelFactoryOfCounterViewModel$Provider(
    this._counterViewModel$Provider,
  );

  final _CounterViewModel$Provider _counterViewModel$Provider;

  @override
  _i13.ViewModelFactory<_i9.CounterViewModel> get() =>
      ({
        required _i13.ViewModelWidgetBuilder<_i9.CounterViewModel> builder,
        _i14.Widget? child,
        _i13.ViewModelErrorBuilder? error,
        _i13.ViewModelInitializer<_i9.CounterViewModel>? init,
        _i11.Key? key,
        _i14.Widget? loading,
      }) => _i13.ViewModelBuilder<_i9.CounterViewModel>(
        key: key,
        viewModelProvider: _counterViewModel$Provider,
        init: init,
        loading: loading,
        error: error,
        builder: builder,
        child: child,
      );
}
