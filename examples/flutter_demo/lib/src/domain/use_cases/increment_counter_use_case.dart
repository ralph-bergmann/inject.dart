import 'package:counter_analytics/counter_analytics.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../../data/repositories/counter_repository.dart';
import '../models/counter.dart';

/// Encapsulates the counter-increment operation.
///
/// Marked `@singleton`: a use case is **stateless** — it holds only references
/// to its collaborators ([CounterRepository]) and keeps no per-consumer mutable
/// state — so one shared instance is safe and avoids needless allocations.
/// Whether a binding should be a singleton depends on whether it carries such
/// mutable state, **not** on the lifecycles of its dependencies. (A use case
/// that *did* hold consumer-specific state would drop `@singleton` and get a
/// fresh instance per injection instead.)
///
/// For on-demand, caller-driven creation, inject a [Provider<T>] — either as a
/// component entry point (see `MainComponent.counterRepositoryProvider`) or as
/// an ordinary constructor parameter on any `@inject` class; the generator
/// passes the provider itself, so the consumer decides when to call `.get()`.
@inject
@singleton
class IncrementCounterUseCase {
  const IncrementCounterUseCase({
    required this._repository,
    // [IncrementTracker] comes from the local `counter_analytics` package —
    // a library package with no code generation of its own. The generator
    // resolves @inject classes across package boundaries; the providers are
    // emitted into this app's main.inject.dart.
    required this._tracker,
  });

  final CounterRepository _repository;
  final IncrementTracker _tracker;

  Future<Counter> execute() async {
    await _repository.increment();
    final counter = await _repository.counter;
    _tracker.onIncrement(counter.value);
    return counter;
  }
}
