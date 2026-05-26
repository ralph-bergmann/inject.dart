import 'package:inject_annotation/inject_annotation.dart';

import 'provider_entry_point_component.inject.dart' as g;

class CoffeeMaker {}

class CoffeeModule {
  @module
  const CoffeeModule();

  @provides
  CoffeeMaker coffee() => CoffeeMaker();
}

@Component([CoffeeModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  Provider<CoffeeMaker> get coffeeMaker;
}
