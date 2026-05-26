import 'package:inject_annotation/inject_annotation.dart';

import 'debug_graph.inject.dart' as g;

// Fixture for the debug_graph pipeline test.
//
// Diamond topology:
//   CoffeeShop
//   ├── Brewer (@singleton, @async) → Heater (@singleton)
//   └── Grinder                    → Heater (@singleton)
//
// Heater is shared (2 receivers: Brewer, Grinder) → appears as Heater...
// in the main tree and gets a shared-bindings block entry.

@Component([CoffeeModule])
abstract class CoffeeShop {
  static const create = g.CoffeeShop$Component.create;

  @inject
  Future<Brewer> get brewer;

  @inject
  Grinder get grinder;
}

@module
class CoffeeModule {
  const CoffeeModule();

  @provides
  @singleton
  @asynchronous
  Future<Brewer> provideBrewer(Heater heater) async => Brewer(heater);

  @provides
  Grinder provideGrinder(Heater heater) => Grinder(heater);
}

@singleton
@inject
class Heater {
  const Heater();
}

class Brewer {
  const Brewer(this.heater);
  final Heater heater;
}

class Grinder {
  const Grinder(this.heater);
  final Heater heater;
}
