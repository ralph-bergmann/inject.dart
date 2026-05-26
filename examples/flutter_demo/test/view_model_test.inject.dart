// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;

import 'package:flutter_demo/src/data/repositories/counter_repository.dart'
    as _i4;
import 'package:flutter_demo/src/domain/use_cases/increment_counter_use_case.dart'
    as _i6;
import 'package:flutter_demo/src/features/home/counter_view_model.dart' as _i2;
import 'package:inject_annotation/inject_annotation.dart' as _i3;

import 'view_model_test.dart' as _i1;

class TestViewModelComponent$Component implements _i1.TestViewModelComponent {
  factory TestViewModelComponent$Component.create({
    _i1.TestViewModelModule? testViewModelModule,
  }) => TestViewModelComponent$Component._(
    testViewModelModule ?? _i1.TestViewModelModule(),
  );

  TestViewModelComponent$Component._(
    _i1.TestViewModelModule testViewModelModule,
  ) {
    final counterRepository$Provider = _CounterRepository$Provider(
      testViewModelModule,
    );
    final incrementCounterUseCase$Provider = _IncrementCounterUseCase$Provider(
      counterRepository$Provider,
    );
    final futureOfInt$Provider = _FutureOfInt$Provider(testViewModelModule);
    _counterViewModel$Provider = _CounterViewModel$Provider(
      incrementCounterUseCase$Provider,
      futureOfInt$Provider,
    );
  }

  late final _CounterViewModel$Provider _counterViewModel$Provider;

  @override
  _i2.CounterViewModel get counterViewModel => _counterViewModel$Provider.get();
}

class _CounterRepository$Provider
    implements _i3.Provider<_i4.CounterRepository> {
  _CounterRepository$Provider(this._module);

  final _i1.TestViewModelModule _module;

  late final _i4.CounterRepository _singleton = _create();

  _i4.CounterRepository _create() => _module.provideCounterRepository();

  @override
  _i4.CounterRepository get() => _singleton;
}

class _CounterViewModel$Provider implements _i3.Provider<_i2.CounterViewModel> {
  const _CounterViewModel$Provider(
    this._incrementCounterUseCase$Provider,
    this._futureOfInt$Provider,
  );

  final _IncrementCounterUseCase$Provider _incrementCounterUseCase$Provider;

  final _FutureOfInt$Provider _futureOfInt$Provider;

  @override
  _i2.CounterViewModel get() => _i2.CounterViewModel(
    incrementUseCase: _incrementCounterUseCase$Provider.get(),
    initialCount: _futureOfInt$Provider.get(),
  );
}

class _FutureOfInt$Provider implements _i3.Provider<_i5.Future<int>> {
  const _FutureOfInt$Provider(this._module);

  final _i1.TestViewModelModule _module;

  @override
  _i5.Future<int> get() => _module.provideInitialCount();
}

class _IncrementCounterUseCase$Provider
    implements _i3.Provider<_i6.IncrementCounterUseCase> {
  _IncrementCounterUseCase$Provider(this._counterRepository$Provider);

  final _CounterRepository$Provider _counterRepository$Provider;

  late final _i6.IncrementCounterUseCase _singleton = _create();

  _i6.IncrementCounterUseCase _create() => _i6.IncrementCounterUseCase(
    repository: _counterRepository$Provider.get(),
  );

  @override
  _i6.IncrementCounterUseCase get() => _singleton;
}
