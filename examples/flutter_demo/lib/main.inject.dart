// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i8;

import 'package:counter_analytics/src/analytics_module.dart' as _i4;
import 'package:counter_analytics/src/analytics_service.dart' as _i10;
import 'package:counter_analytics/src/increment_tracker.dart' as _i15;
import 'package:flutter/src/foundation/key.dart' as _i13;
import 'package:flutter/src/widgets/framework.dart' as _i17;
import 'package:inject_annotation/inject_annotation.dart' as _i9;
import 'package:inject_annotation/src/api/provider.dart' as _i5;
import 'package:inject_flutter/src/view_model_factory.dart' as _i16;

import 'main.dart' as _i1;
import 'src/app_module.dart' as _i2;
import 'src/data/repositories/counter_repository.dart' as _i6;
import 'src/data/services/database.dart' as _i3;
import 'src/domain/use_cases/increment_counter_use_case.dart' as _i14;
import 'src/features/app/my_app.dart' as _i7;
import 'src/features/home/counter_view_model.dart' as _i11;
import 'src/features/home/home_page.dart' as _i12;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({
    _i2.AppModule? appModule,
    _i3.DatabaseModule? databaseModule,
    required _i4.AnalyticsModule analyticsModule,
  }) => MainComponent$Component._(
    appModule ?? _i2.AppModule(),
    databaseModule ?? _i3.DatabaseModule(),
    analyticsModule,
  );

  MainComponent$Component._(
    _i2.AppModule appModule,
    _i3.DatabaseModule databaseModule,
    _i4.AnalyticsModule analyticsModule,
  ) {
    final analyticsService$Provider = _AnalyticsService$Provider(
      analyticsModule,
    );
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
    final incrementTracker$Provider = _IncrementTracker$Provider(
      analyticsService$Provider,
    );
    final incrementCounterUseCase$Provider = _IncrementCounterUseCase$Provider(
      _counterRepository$Provider,
      incrementTracker$Provider,
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
  _i5.Provider<_i6.CounterRepository> get counterRepositoryProvider =>
      _counterRepository$Provider;

  @override
  _i2.CreationLogListener get creationLogListener =>
      _creationLogListener$Provider.get();

  @override
  _i7.MyAppFactory get myAppFactory => _myAppFactory$Provider.get();

  @override
  _i8.Future<String> get welcomeMessage => _stringWelcome$Provider.get();
}

class _AnalyticsService$Provider
    implements _i9.Provider<_i10.AnalyticsService> {
  _AnalyticsService$Provider(this._module);

  final _i4.AnalyticsModule _module;

  late final _i10.AnalyticsService _singleton = _create();

  _i10.AnalyticsService _create() => _module.provideAnalyticsService();

  @override
  _i10.AnalyticsService get() => _singleton;
}

class _AppInfo$Provider implements _i9.Provider<_i8.Future<_i2.AppInfo>> {
  _AppInfo$Provider(this._module);

  final _i2.AppModule _module;

  _i8.Future<_i2.AppInfo>? _singletonFuture;

  _i8.Future<_i2.AppInfo> _create() => _module.provideAppInfo();

  @override
  _i8.Future<_i2.AppInfo> get() => _singletonFuture ??= _create();
}

class _CounterRepository$Provider
    implements _i9.Provider<_i6.CounterRepository> {
  _CounterRepository$Provider(this._database$Provider);

  final _Database$Provider _database$Provider;

  late final _i6.CounterRepository _singleton = _create();

  _i6.CounterRepository _create() =>
      _i6.CounterRepository(database: _database$Provider.get());

  @override
  _i6.CounterRepository get() => _singleton;
}

class _CounterViewModel$Provider
    implements _i9.Provider<_i11.CounterViewModel> {
  const _CounterViewModel$Provider(
    this._incrementCounterUseCase$Provider,
    this._futureOfInt$Provider,
    this._creationLogListener$Provider,
  );

  final _IncrementCounterUseCase$Provider _incrementCounterUseCase$Provider;

  final _FutureOfInt$Provider _futureOfInt$Provider;

  final _CreationLogListener$Provider _creationLogListener$Provider;

  @override
  _i11.CounterViewModel get() {
    final instance = _i11.CounterViewModel(
      incrementUseCase: _incrementCounterUseCase$Provider.get(),
      initialCount: _futureOfInt$Provider.get(),
    );
    _creationLogListener$Provider.get().onProvision(instance);
    return instance;
  }
}

class _CreationLogListener$Provider
    implements _i9.Provider<_i2.CreationLogListener> {
  _CreationLogListener$Provider(this._module);

  final _i2.AppModule _module;

  late final _i2.CreationLogListener _singleton = _create();

  _i2.CreationLogListener _create() => _module.provideCreationLogListener();

  @override
  _i2.CreationLogListener get() => _singleton;
}

class _Database$Provider implements _i9.Provider<_i3.Database> {
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

class _FutureOfInt$Provider implements _i9.Provider<_i8.Future<int>> {
  _FutureOfInt$Provider(this._module);

  final _i2.AppModule _module;

  late final _i8.Future<int> _singleton = _create();

  _i8.Future<int> _create() => _module.provideInitialCount();

  @override
  _i8.Future<int> get() => _singleton;
}

class _HomePageFactory$Factory implements _i12.HomePageFactory {
  const _HomePageFactory$Factory(
    this._viewModelFactoryOfCounterViewModel$Provider,
  );

  final _ViewModelFactoryOfCounterViewModel$Provider
  _viewModelFactoryOfCounterViewModel$Provider;

  @override
  _i12.HomePage create({_i13.Key? key, required String title}) => _i12.HomePage(
    key: key,
    title: title,
    viewModelFactory: _viewModelFactoryOfCounterViewModel$Provider.get(),
  );
}

class _HomePageFactory$Provider implements _i9.Provider<_i12.HomePageFactory> {
  _HomePageFactory$Provider(this._viewModelFactoryOfCounterViewModel$Provider);

  final _ViewModelFactoryOfCounterViewModel$Provider
  _viewModelFactoryOfCounterViewModel$Provider;

  late final _i12.HomePageFactory _factory = _HomePageFactory$Factory(
    _viewModelFactoryOfCounterViewModel$Provider,
  );

  @override
  _i12.HomePageFactory get() => _factory;
}

class _IncrementCounterUseCase$Provider
    implements _i9.Provider<_i14.IncrementCounterUseCase> {
  _IncrementCounterUseCase$Provider(
    this._counterRepository$Provider,
    this._incrementTracker$Provider,
  );

  final _CounterRepository$Provider _counterRepository$Provider;

  final _IncrementTracker$Provider _incrementTracker$Provider;

  late final _i14.IncrementCounterUseCase _singleton = _create();

  _i14.IncrementCounterUseCase _create() => _i14.IncrementCounterUseCase(
    repository: _counterRepository$Provider.get(),
    tracker: _incrementTracker$Provider.get(),
  );

  @override
  _i14.IncrementCounterUseCase get() => _singleton;
}

class _IncrementTracker$Provider
    implements _i9.Provider<_i15.IncrementTracker> {
  _IncrementTracker$Provider(this._analyticsService$Provider);

  final _AnalyticsService$Provider _analyticsService$Provider;

  late final _i15.IncrementTracker _singleton = _create();

  _i15.IncrementTracker _create() =>
      _i15.IncrementTracker(_analyticsService$Provider.get());

  @override
  _i15.IncrementTracker get() => _singleton;
}

class _MyAppFactory$Factory implements _i7.MyAppFactory {
  const _MyAppFactory$Factory(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  @override
  _i7.MyApp create({_i13.Key? key}) =>
      _i7.MyApp(key: key, homePageFactory: _homePageFactory$Provider.get());
}

class _MyAppFactory$Provider implements _i9.Provider<_i7.MyAppFactory> {
  _MyAppFactory$Provider(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  late final _i7.MyAppFactory _factory = _MyAppFactory$Factory(
    _homePageFactory$Provider,
  );

  @override
  _i7.MyAppFactory get() => _factory;
}

class _StringDatabaseName$Provider implements _i9.Provider<String> {
  const _StringDatabaseName$Provider(this._module);

  final _i3.DatabaseModule _module;

  @override
  String get() => _module.provideDatabaseName();
}

class _StringDatabasePath$Provider implements _i9.Provider<String> {
  const _StringDatabasePath$Provider(this._module);

  final _i3.DatabaseModule _module;

  @override
  String get() => _module.provideDatabasePath();
}

class _StringWelcome$Provider implements _i9.Provider<_i8.Future<String>> {
  _StringWelcome$Provider(this._appInfo$Provider, this._module);

  final _AppInfo$Provider _appInfo$Provider;

  final _i2.AppModule _module;

  _i8.Future<String>? _singletonFuture;

  _i8.Future<String> _create() async =>
      _module.provideWelcomeMessage(await _appInfo$Provider.get());

  @override
  _i8.Future<String> get() => _singletonFuture ??= _create();
}

class _ViewModelFactoryOfCounterViewModel$Provider
    implements _i9.Provider<_i16.ViewModelFactory<_i11.CounterViewModel>> {
  const _ViewModelFactoryOfCounterViewModel$Provider(
    this._counterViewModel$Provider,
  );

  final _CounterViewModel$Provider _counterViewModel$Provider;

  @override
  _i16.ViewModelFactory<_i11.CounterViewModel> get() =>
      ({
        required _i16.ViewModelWidgetBuilder<_i11.CounterViewModel> builder,
        _i17.Widget? child,
        _i16.ViewModelErrorBuilder? error,
        _i16.ViewModelInitializer<_i11.CounterViewModel>? init,
        _i13.Key? key,
        _i17.Widget? loading,
      }) => _i16.ViewModelBuilder<_i11.CounterViewModel>(
        key: key,
        viewModelProvider: _counterViewModel$Provider,
        init: init,
        loading: loading,
        error: error,
        builder: builder,
        child: child,
      );
}
