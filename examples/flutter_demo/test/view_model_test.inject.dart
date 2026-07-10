// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;

import 'package:counter_analytics/src/analytics_service.dart' as _i4;
import 'package:counter_analytics/src/increment_tracker.dart' as _i8;
import 'package:flutter_demo/src/data/repositories/counter_repository.dart'
    as _i5;
import 'package:flutter_demo/src/domain/use_cases/increment_counter_use_case.dart'
    as _i7;
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
    final analyticsService$Provider = _AnalyticsService$Provider(
      testViewModelModule,
    );
    final counterRepository$Provider = _CounterRepository$Provider(
      testViewModelModule,
    );
    final incrementTracker$Provider = _IncrementTracker$Provider(
      analyticsService$Provider,
    );
    final incrementCounterUseCase$Provider = _IncrementCounterUseCase$Provider(
      counterRepository$Provider,
      incrementTracker$Provider,
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

class _AnalyticsService$Provider implements _i3.Provider<_i4.AnalyticsService> {
  _AnalyticsService$Provider(this._module);

  final _i1.TestViewModelModule _module;

  late final _i4.AnalyticsService _singleton = _create();

  _i4.AnalyticsService _create() => _module.provideAnalyticsService();

  @override
  _i4.AnalyticsService get() => _singleton;
}

class _CounterRepository$Provider
    implements _i3.Provider<_i5.CounterRepository> {
  _CounterRepository$Provider(this._module);

  final _i1.TestViewModelModule _module;

  late final _i5.CounterRepository _singleton = _create();

  _i5.CounterRepository _create() => _module.provideCounterRepository();

  @override
  _i5.CounterRepository get() => _singleton;
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

class _FutureOfInt$Provider implements _i3.Provider<_i6.Future<int>> {
  const _FutureOfInt$Provider(this._module);

  final _i1.TestViewModelModule _module;

  @override
  _i6.Future<int> get() => _module.provideInitialCount();
}

class _IncrementCounterUseCase$Provider
    implements _i3.Provider<_i7.IncrementCounterUseCase> {
  _IncrementCounterUseCase$Provider(
    this._counterRepository$Provider,
    this._incrementTracker$Provider,
  );

  final _CounterRepository$Provider _counterRepository$Provider;

  final _IncrementTracker$Provider _incrementTracker$Provider;

  late final _i7.IncrementCounterUseCase _singleton = _create();

  _i7.IncrementCounterUseCase _create() => _i7.IncrementCounterUseCase(
    repository: _counterRepository$Provider.get(),
    tracker: _incrementTracker$Provider.get(),
  );

  @override
  _i7.IncrementCounterUseCase get() => _singleton;
}

class _IncrementTracker$Provider implements _i3.Provider<_i8.IncrementTracker> {
  _IncrementTracker$Provider(this._analyticsService$Provider);

  final _AnalyticsService$Provider _analyticsService$Provider;

  late final _i8.IncrementTracker _singleton = _create();

  _i8.IncrementTracker _create() =>
      _i8.IncrementTracker(_analyticsService$Provider.get());

  @override
  _i8.IncrementTracker get() => _singleton;
}
