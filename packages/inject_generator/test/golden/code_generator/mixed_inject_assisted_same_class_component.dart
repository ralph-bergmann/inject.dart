import 'package:inject_annotation/inject_annotation.dart';

import 'mixed_inject_assisted_same_class_component.inject.dart' as g;

class Heater {
  @inject
  Heater();
}

/// A class that uses both @inject (standard DI) and @assistedInject
/// (factory-created) on different constructors of the same class.
class CoffeeMaker {
  @inject
  CoffeeMaker(this.heater) : blend = 'default';

  @assistedInject
  CoffeeMaker.custom(this.heater, @assisted this.blend);

  final Heater heater;
  final String blend;
}

@assistedFactory
abstract class CoffeeMakerFactory {
  CoffeeMaker create(String blend);
}

@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  /// Standard DI — resolved via @inject constructor
  @inject
  CoffeeMaker get coffeeMaker;

  /// Factory — resolved via @assistedInject .custom constructor
  @inject
  CoffeeMakerFactory get coffeeMakerFactory;
}
