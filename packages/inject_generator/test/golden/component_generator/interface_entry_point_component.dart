import 'package:inject_annotation/inject_annotation.dart';

import 'interface_entry_point_component.inject.dart' as g;

class CoffeeMaker {}

abstract class CoffeeServiceLocator {
  @inject
  CoffeeMaker get coffeeMaker;
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
