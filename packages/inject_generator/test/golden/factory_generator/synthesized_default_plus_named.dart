import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_default_plus_named.inject.dart' as g;

part 'synthesized_default_plus_named.factory.dart';

@inject
class Heater {}

class CoffeeMaker {
  @Qualifier(#standard)
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name) : strength = 0;

  @Qualifier(#detail)
  @assistedInject
  CoffeeMaker.detail(this.heater, @assisted this.strength) : name = '';

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
  CoffeeMakerDetailFactory get detailCoffeeMakerFactory;
}
