import 'package:inject_annotation/inject_annotation.dart';

import 'mixed_factory_inject_component.inject.dart' as g;

class Heater {
  @inject
  Heater();
}

class Grinder {
  @inject
  Grinder();
}

class CoffeeMaker {
  @inject
  CoffeeMaker(this.heater, this.grinder);

  Heater heater;

  Grinder grinder;
}

class Latte {
  @assistedInject
  Latte(this.grinder, @assisted this.name);

  Grinder grinder;

  String name;
}

@assistedFactory
abstract class LatteFactory {
  Latte create(String name);
}

@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;

  @inject
  LatteFactory get latteFactory;
}
