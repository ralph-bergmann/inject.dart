import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_multi_constructor.inject.dart' as g;

part 'synthesized_multi_constructor.factory.dart';

const standardCoffeeMaker = Qualifier(#standard);
const frenchCoffeeMaker = Qualifier(#french);

@inject
class Heater {}

class CoffeeMaker {
  @standardCoffeeMaker
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name) : strength = 0;

  @frenchCoffeeMaker
  @assistedInject
  CoffeeMaker.french(this.heater, @assisted this.strength) : name = '';

  final Heater heater;
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
