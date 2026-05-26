import 'package:inject_annotation/inject_annotation.dart';

import 'multi_entry_point_same_type_component.inject.dart' as g;

class CoffeeMaker {}

abstract class CoffeeServiceLocator {
  @inject
  CoffeeMaker get regularCoffee;

  @inject
  CoffeeMaker get decafCoffee;
}

class CoffeeModule {
  @module
  const CoffeeModule();

  @provides
  CoffeeMaker coffee() => CoffeeMaker();
}

@Component([CoffeeModule])
abstract class MyComponent implements CoffeeServiceLocator {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;
}
