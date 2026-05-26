import 'package:inject_annotation/inject_annotation.dart';

import 'singleton_component.inject.dart' as g;

class CoffeeMaker {}

@module
class CoffeeModule {
  @provides
  @singleton
  CoffeeMaker provideCoffeeMaker() => CoffeeMaker();
}

@Component([CoffeeModule])
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;
}
