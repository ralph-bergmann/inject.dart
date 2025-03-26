// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'main.dart' as _i1;
import 'src/data/services/database.dart' as _i2;
import 'src/features/app/my_app.dart' as _i3;
import 'package:inject_annotation/inject_annotation.dart' as _i4;
import 'src/data/repositories/counter_repository.dart' as _i5;
import 'src/features/home/my_home_page_view_model.dart' as _i6;
import 'package:inject_flutter/src/view_model_factory.dart' as _i7;
import 'package:inject_flutter/inject_flutter.dart' as _i8;
import 'src/features/home/my_home_page.dart' as _i9;
import 'package:flutter/src/foundation/key.dart' as _i10;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create(
          {_i2.DataBaseModule? dataBaseModule}) =>
      MainComponent$Component._(dataBaseModule ?? _i2.DataBaseModule());

  MainComponent$Component._(_i2.DataBaseModule dataBaseModule) {
    final database$Provider = _Database$Provider(dataBaseModule);
    final counterRepository$Provider =
        _CounterRepository$Provider(database$Provider);
    final myHomePageViewModel$Provider =
        _MyHomePageViewModel$Provider(counterRepository$Provider);
    final viewModelFactoryMyHomePageViewModel$Provider =
        _ViewModelFactoryMyHomePageViewModel$Provider(
            myHomePageViewModel$Provider);
    final myHomePageFactory$Provider = _MyHomePageFactory$Provider(
        viewModelFactoryMyHomePageViewModel$Provider);
    _myAppFactory$Provider = _MyAppFactory$Provider(myHomePageFactory$Provider);
  }

  late final _MyAppFactory$Provider _myAppFactory$Provider;

  @override
  _i3.MyAppFactory get myAppFactory => _myAppFactory$Provider.get();
}

class _Database$Provider implements _i4.Provider<_i2.Database> {
  _Database$Provider(this._module);

  final _i2.DataBaseModule _module;

  _i2.Database? _singleton;

  @override
  _i2.Database get() => _singleton ??= _module.provideDatabase();
}

class _CounterRepository$Provider
    implements _i4.Provider<_i5.CounterRepository> {
  _CounterRepository$Provider(this._database$Provider);

  final _Database$Provider _database$Provider;

  _i5.CounterRepository? _singleton;

  @override
  _i5.CounterRepository get() =>
      _singleton ??= _i5.CounterRepository(database: _database$Provider.get());
}

class _MyHomePageViewModel$Provider
    implements _i4.Provider<_i6.MyHomePageViewModel> {
  const _MyHomePageViewModel$Provider(this._counterRepository$Provider);

  final _CounterRepository$Provider _counterRepository$Provider;

  @override
  _i6.MyHomePageViewModel get() =>
      _i6.MyHomePageViewModel(repository: _counterRepository$Provider.get());
}

class _ViewModelFactoryMyHomePageViewModel$Provider
    implements _i4.Provider<_i7.ViewModelFactory<_i6.MyHomePageViewModel>> {
  _ViewModelFactoryMyHomePageViewModel$Provider(
      this._myHomePageViewModel$Provider);

  final _MyHomePageViewModel$Provider _myHomePageViewModel$Provider;

  late final _i7.ViewModelFactory<_i6.MyHomePageViewModel> _factory = ({
    key,
    required builder,
    child,
  }) =>
      _i8.ViewModelBuilder<_i6.MyHomePageViewModel>(
        key: key,
        viewModelProvider: _myHomePageViewModel$Provider,
        builder: builder,
        child: child,
      );

  @override
  _i7.ViewModelFactory<_i6.MyHomePageViewModel> get() => _factory;
}

class _MyHomePageFactory$Provider
    implements _i4.Provider<_i9.MyHomePageFactory> {
  _MyHomePageFactory$Provider(
      this._viewModelFactoryMyHomePageViewModel$Provider);

  final _ViewModelFactoryMyHomePageViewModel$Provider
      _viewModelFactoryMyHomePageViewModel$Provider;

  late final _i9.MyHomePageFactory _factory =
      _MyHomePageFactory$Factory(_viewModelFactoryMyHomePageViewModel$Provider);

  @override
  _i9.MyHomePageFactory get() => _factory;
}

class _MyHomePageFactory$Factory implements _i9.MyHomePageFactory {
  const _MyHomePageFactory$Factory(
      this._viewModelFactoryMyHomePageViewModel$Provider);

  final _ViewModelFactoryMyHomePageViewModel$Provider
      _viewModelFactoryMyHomePageViewModel$Provider;

  @override
  _i9.MyHomePage create({
    _i10.Key? key,
    required String title,
  }) =>
      _i9.MyHomePage(
        key: key,
        title: title,
        viewModelFactory: _viewModelFactoryMyHomePageViewModel$Provider.get(),
      );
}

class _MyAppFactory$Provider implements _i4.Provider<_i3.MyAppFactory> {
  _MyAppFactory$Provider(this._myHomePageFactory$Provider);

  final _MyHomePageFactory$Provider _myHomePageFactory$Provider;

  late final _i3.MyAppFactory _factory =
      _MyAppFactory$Factory(_myHomePageFactory$Provider);

  @override
  _i3.MyAppFactory get() => _factory;
}

class _MyAppFactory$Factory implements _i3.MyAppFactory {
  const _MyAppFactory$Factory(this._myHomePageFactory$Provider);

  final _MyHomePageFactory$Provider _myHomePageFactory$Provider;

  @override
  _i3.MyApp create({_i10.Key? key}) => _i3.MyApp(
        key: key,
        homePageFactory: _myHomePageFactory$Provider.get(),
      );
}
