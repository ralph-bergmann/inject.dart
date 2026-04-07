import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_multi_constructor_component.inject.dart' as g;

part 'synthesized_multi_constructor_component.factory.dart';

const standardCoffeeMaker = Qualifier(#standard);
const frenchCoffeeMaker = Qualifier(#french);

class Heater {
  @inject
  Heater();
}

class CoffeeMaker {
  @standardCoffeeMaker
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name) : strength = 1;

  @frenchCoffeeMaker
  @assistedInject
  CoffeeMaker.french(this.heater, @assisted this.strength) : name = 'name';

  final Heater heater;
  final String name;
  final int strength;
}

@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  CoffeeMakerStandardFactory get standardCoffeeMakerFactory;

  @inject
  CoffeeMakerFrenchFactory get frenchCoffeeMakerFactory;
}
