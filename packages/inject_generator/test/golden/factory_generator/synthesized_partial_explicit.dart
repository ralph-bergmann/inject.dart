import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_partial_explicit.inject.dart' as g;

part 'synthesized_partial_explicit.factory.dart';

@inject
class Heater {}

class CoffeeMaker {
  @Qualifier(#standard)
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name) : strength = 0;

  @Qualifier(#french)
  @assistedInject
  CoffeeMaker.french(this.heater, @assisted this.strength) : name = '';

  final Heater heater;
  final String name;
  final int strength;
}

/// Explicit factory covers the #standard constructor only.
/// The #french constructor is unmatched and gets a synthesized CoffeeMakerFrenchFactory.
@assistedFactory
abstract class CoffeeMakerStandardFactory {
  @Qualifier(#standard)
  CoffeeMaker create(String name);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeMakerStandardFactory get standardCoffeeMakerFactory;

  @inject
  CoffeeMakerFrenchFactory get frenchCoffeeMakerFactory;
}
