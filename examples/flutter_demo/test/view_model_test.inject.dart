// ignore_for_file: implementation_imports
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter_demo/src/data/repositories/counter_repository.dart'
    as _i4;
import 'package:flutter_demo/src/features/home/my_home_page_view_model.dart'
    as _i2;
import 'package:inject_annotation/inject_annotation.dart' as _i3;

import 'view_model_test.dart' as _i1;

class ViewModelTestComponent$Component implements _i1.ViewModelTestComponent {
  factory ViewModelTestComponent$Component.create(
          {_i1.TestModule? testModule}) =>
      ViewModelTestComponent$Component._(testModule ?? _i1.TestModule());

  ViewModelTestComponent$Component._(_i1.TestModule testModule) {
    final counterRepository$Provider = _CounterRepository$Provider(testModule);
    _myHomePageViewModel$Provider =
        _MyHomePageViewModel$Provider(counterRepository$Provider);
  }

  late final _MyHomePageViewModel$Provider _myHomePageViewModel$Provider;

  @override
  _i2.MyHomePageViewModel get homeViewModel =>
      _myHomePageViewModel$Provider.get();
}

class _CounterRepository$Provider
    implements _i3.Provider<_i4.CounterRepository> {
  _CounterRepository$Provider(this._module);

  final _i1.TestModule _module;

  _i4.CounterRepository? _singleton;

  @override
  _i4.CounterRepository get() =>
      _singleton ??= _module.provideCounterRepository();
}

class _MyHomePageViewModel$Provider
    implements _i3.Provider<_i2.MyHomePageViewModel> {
  const _MyHomePageViewModel$Provider(this._counterRepository$Provider);

  final _CounterRepository$Provider _counterRepository$Provider;

  @override
  _i2.MyHomePageViewModel get() =>
      _i2.MyHomePageViewModel(repository: _counterRepository$Provider.get());
}
