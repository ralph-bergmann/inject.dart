// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'main.dart' as _i1;
import 'package:inject_annotation/inject_annotation.dart' as _i2;
import 'package:inject_flutter/src/view_model_factory.dart' as _i3;
import 'package:inject_flutter/inject_flutter.dart' as _i4;
import 'package:flutter/src/foundation/key.dart' as _i5;

class MainComponent$Component implements _i1.AppComponent {
  factory MainComponent$Component.create() => MainComponent$Component._();

  MainComponent$Component._() {
    final homePageViewModel$Provider = _HomePageViewModel$Provider();
    final viewModelFactoryHomePageViewModel$Provider =
        _ViewModelFactoryHomePageViewModel$Provider(homePageViewModel$Provider);
    final homePageFactory$Provider =
        _HomePageFactory$Provider(viewModelFactoryHomePageViewModel$Provider);
    _exampleAppFactory$Provider =
        _ExampleAppFactory$Provider(homePageFactory$Provider);
  }

  late final _ExampleAppFactory$Provider _exampleAppFactory$Provider;

  @override
  _i1.ExampleAppFactory get exampleAppFactory =>
      _exampleAppFactory$Provider.get();
}

class _HomePageViewModel$Provider
    implements _i2.Provider<_i1.HomePageViewModel> {
  const _HomePageViewModel$Provider();

  @override
  _i1.HomePageViewModel get() => _i1.HomePageViewModel();
}

class _ViewModelFactoryHomePageViewModel$Provider
    implements _i2.Provider<_i3.ViewModelFactory<_i1.HomePageViewModel>> {
  _ViewModelFactoryHomePageViewModel$Provider(this._homePageViewModel$Provider);

  final _HomePageViewModel$Provider _homePageViewModel$Provider;

  late final _i3.ViewModelFactory<_i1.HomePageViewModel> _factory = ({
    key,
    required builder,
    child,
  }) =>
      _i4.ViewModelBuilder<_i1.HomePageViewModel>(
        key: key,
        viewModelProvider: _homePageViewModel$Provider,
        builder: builder,
        child: child,
      );

  @override
  _i3.ViewModelFactory<_i1.HomePageViewModel> get() => _factory;
}

class _HomePageFactory$Provider implements _i2.Provider<_i1.HomePageFactory> {
  _HomePageFactory$Provider(this._viewModelFactoryHomePageViewModel$Provider);

  final _ViewModelFactoryHomePageViewModel$Provider
      _viewModelFactoryHomePageViewModel$Provider;

  late final _i1.HomePageFactory _factory =
      _HomePageFactory$Factory(_viewModelFactoryHomePageViewModel$Provider);

  @override
  _i1.HomePageFactory get() => _factory;
}

class _HomePageFactory$Factory implements _i1.HomePageFactory {
  const _HomePageFactory$Factory(
      this._viewModelFactoryHomePageViewModel$Provider);

  final _ViewModelFactoryHomePageViewModel$Provider
      _viewModelFactoryHomePageViewModel$Provider;

  @override
  _i1.HomePage create({
    _i5.Key? key,
    required String title,
  }) =>
      _i1.HomePage(
        key: key,
        title: title,
        viewModelFactory: _viewModelFactoryHomePageViewModel$Provider.get(),
      );
}

class _ExampleAppFactory$Provider
    implements _i2.Provider<_i1.ExampleAppFactory> {
  _ExampleAppFactory$Provider(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  late final _i1.ExampleAppFactory _factory =
      _ExampleAppFactory$Factory(_homePageFactory$Provider);

  @override
  _i1.ExampleAppFactory get() => _factory;
}

class _ExampleAppFactory$Factory implements _i1.ExampleAppFactory {
  const _ExampleAppFactory$Factory(this._homePageFactory$Provider);

  final _HomePageFactory$Provider _homePageFactory$Provider;

  @override
  _i1.ExampleApp create({_i5.Key? key}) => _i1.ExampleApp(
        key: key,
        homePageFactory: _homePageFactory$Provider.get(),
      );
}
