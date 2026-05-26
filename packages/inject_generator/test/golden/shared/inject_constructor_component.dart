import 'package:inject_annotation/inject_annotation.dart';

import 'inject_constructor_component.inject.dart' as g;

class Heater {}

@module
class MyModule {
  @provides
  Heater provideHeater() => Heater();
}

@inject
class CoffeeMaker {
  CoffeeMaker(this.heater);

  Heater heater;
}

@Component([MyModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;
}
