// Golden fixture: `Provider<T>` as an ordinary constructor parameter on a
// regular `@inject` class — injected like any other dependency, never routed
// through the component as an entry point. Three provider shapes are covered:
//
//   * `Provider<Heater>`        — provider of a plain `@inject` type.
//   * `Provider<WaterTank>`     — provider of another `@inject` type.
//   * `Provider<Future<Water>>` — provider of a raw `Future<T>` binding; only
//                                 the outer `Provider` is unwrapped, so the
//                                 inner `Future<Water>` stays intact.
//
// For each shape the generator must pass the provider field *directly* (no
// `.get()`). The `brew()` body exercises the resulting providers, and the
// analyzer pass on the generated `.inject.dart` confirms the wiring type-checks.

import 'package:inject_annotation/inject_annotation.dart';

import 'inject_provider_constructor_param.inject.dart' as g;

@Component([WaterModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function({WaterModule? waterModule}) create = g.AppComponent$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;
}

@inject
class CoffeeMaker {
  const CoffeeMaker({
    required this.heaterProvider,
    required this.waterTankProvider,
  });

  // Two `Provider<T>` constructor parameters, both resolved straight from the
  // graph — the consumer decides when to call `.get()`.
  final Provider<Heater> heaterProvider;
  final Provider<WaterTank> waterTankProvider;

  Future<void> brew() async {
    final WaterTank waterTank = waterTankProvider.get();
    // `waterProvider` is a `Provider<Future<Water>>`: `.get()` yields the raw
    // `Future<Water>`, which is awaited here.
    final Water water = await waterTank.waterProvider.get();
    heaterProvider.get().brew(water);
  }
}

@inject
class Heater {
  const Heater();

  void brew(Water water) {}
}

@inject
class WaterTank {
  const WaterTank({required this.waterProvider});

  // `Provider<Future<Water>>`: the outer `Provider` is unwrapped to the inner
  // `Future<Water>` binding (which is preserved, not unwrapped to `Water`).
  final Provider<Future<Water>> waterProvider;
}

@module
class WaterModule {
  // Raw `Future<Water>` binding (no `@asynchronous`): the binding type stays
  // `Future<Water>`, which is exactly what `Provider<Future<Water>>` resolves to.
  @provides
  Future<Water> provideWater() => Future.value(Water());
}

class Water {}
