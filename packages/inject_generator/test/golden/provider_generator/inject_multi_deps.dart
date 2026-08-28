import 'package:inject_annotation/inject_annotation.dart';

import 'inject_multi_deps.inject.dart' as g;

const brandNameA = Qualifier(#brandNameA);
const brandNameB = Qualifier(#brandNameB);

@inject
class Heater {}

@inject
class Pump {}

class CoffeeMaker {
  CoffeeMaker(this.heater, this.pump);

  final Heater heater;
  final Pump pump;
}

@module
class CoffeeMakerModule {
  @provides
  @brandNameA
  CoffeeMaker provideCoffeeMakerA(Heater heater, Pump pump) => CoffeeMaker(heater, pump);

  @provides
  @brandNameB
  CoffeeMaker provideCoffeeMakerB(Heater heater, Pump pump) => CoffeeMaker(heater, pump);
}

@Component([CoffeeMakerModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function({CoffeeMakerModule? coffeeMakerModule}) create =
      g.AppComponent$Component.create;

  @inject
  @brandNameA
  CoffeeMaker get coffeeMaker;
}
