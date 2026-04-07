import 'package:inject_annotation/inject_annotation.dart';

import 'debug_graph_multi.inject.dart' as g;

// Fixture for the multi-component debug_graph pipeline test. Two @components
// in one library with disjoint graphs exercise the per-component loop in
// InjectBuilder.generate() and verify that each component gets its own tree
// (separated by a blank line) and that GraphValidator's `_last*` snapshots
// survive across iterations.

@Component([CoffeeModule])
abstract class CoffeeShop {
  static const create = g.CoffeeShop$Component.create;

  @inject
  Brewer get brewer;
}

@Component([TeaModule])
abstract class TeaShop {
  static const create = g.TeaShop$Component.create;

  @inject
  Steeper get steeper;
}

@module
class CoffeeModule {
  const CoffeeModule();

  @provides
  @singleton
  Heater provideHeater() => const Heater();

  @provides
  Brewer provideBrewer(Heater heater) => Brewer(heater);
}

@module
class TeaModule {
  const TeaModule();

  @provides
  Kettle provideKettle() => const Kettle();

  @provides
  Steeper provideSteeper(Kettle kettle) => Steeper(kettle);
}

class Heater {
  const Heater();
}

class Brewer {
  const Brewer(this.heater);
  final Heater heater;
}

class Kettle {
  const Kettle();
}

class Steeper {
  const Steeper(this.kettle);
  final Kettle kettle;
}
