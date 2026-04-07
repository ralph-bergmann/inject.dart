import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../../domain/models/counter.dart';
import '../../domain/use_cases/increment_counter_use_case.dart';

/// ViewModel backing [HomePage].
///
/// Holds all mutable state; the View ([HomePage]) stays a [StatelessWidget].
/// [ViewModelFactory] creates a fresh instance per [HomePage] widget,
/// invokes the `init:` callback you pass once in [State.initState] (here
/// [HomePage] wires `init: (vm) => vm.init()`), wires [ListenableBuilder] so
/// the widget rebuilds on [notifyListeners], and disposes this VM in
/// [State.dispose].
@inject
class CounterViewModel extends ChangeNotifier {
  CounterViewModel({
    required this._incrementUseCase,
    // Future<int> WITHOUT @asynchronous: inject.dart passes the raw Future
    // as the binding. The generator does not unwrap it — this ViewModel
    // holds a Future<int> and resolves it explicitly in [init].
    //
    // Why is this Future<int> safe for ViewModelFactory, while a Future<T>
    // that depends on an @asynchronous binding would not be?
    // Because [AppModule.provideInitialCount] has NO transitive async deps.
    // inject.dart tracks the full provider chain: if ANY dep is @asynchronous,
    // ViewModelFactory rejects it (it needs synchronous provider resolution).
    // [provideInitialCount] is purely sync to *provision* — it just returns
    // a pre-resolved Future<int> — so no async taint propagates.
    required this._initialCount,
  });

  final IncrementCounterUseCase _incrementUseCase;
  final Future<int> _initialCount;

  Counter _counter = const Counter();

  /// Current counter state as an immutable [Counter] domain model.
  Counter get counter => _counter;

  /// Runs once when the ViewModel is created. [HomePage] wires this in via
  /// `init: (vm) => vm.init()`; because it is asynchronous, [ViewModelBuilder]
  /// awaits it (showing its `loading` widget meanwhile) before building the UI.
  /// The factory does not call this automatically — you must pass `init:`.
  ///
  /// Awaits the [Future<int>] binding — inject.dart did NOT unwrap this
  /// future (no [@asynchronous] on [AppModule.provideInitialCount]), so
  /// the ViewModel holds the raw [Future] and resolves it here.
  Future<void> init() async {
    _counter = Counter(value: await _initialCount);
    notifyListeners();
  }

  Future<void> increment() async {
    _counter = await _incrementUseCase.execute();
    notifyListeners();
  }
}
