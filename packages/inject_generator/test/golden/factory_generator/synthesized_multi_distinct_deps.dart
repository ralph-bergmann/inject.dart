import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_multi_distinct_deps.inject.dart' as g;

part 'synthesized_multi_distinct_deps.factory.dart';

@inject
class Heater {}

@inject
class Grinder {}

class CoffeeMaker {
  @Qualifier(#standard)
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name) : grinder = Grinder(), strength = 0;

  @Qualifier(#french)
  @assistedInject
  CoffeeMaker.french(this.grinder, @assisted this.strength) : heater = Heater(), name = '';

  final Heater heater;
  final Grinder grinder;
  final String name;
  final int strength;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeMakerStandardFactory get standardCoffeeMakerFactory;

  @inject
  CoffeeMakerFrenchFactory get frenchCoffeeMakerFactory;
}
