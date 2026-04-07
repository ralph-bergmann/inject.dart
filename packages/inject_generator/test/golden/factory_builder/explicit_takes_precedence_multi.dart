import 'package:inject_annotation/inject_annotation.dart';

import 'explicit_takes_precedence_multi.inject.dart' as g;

const standardCoffeeMaker = Qualifier(#standard);
const frenchCoffeeMaker = Qualifier(#french);

@inject
class Heater {}

class CoffeeMaker {
  @standardCoffeeMaker
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name) : strength = 1;

  @frenchCoffeeMaker
  @assistedInject
  CoffeeMaker.french(this.heater, @assisted this.strength) : name = 'name';

  final Heater heater;
  final String name;
  final int strength;
}

/// Explicit factory targets only the #standard constructor.
/// The #french constructor is unmatched, but the hasExplicitFactory guard
/// must prevent a synthesized CoffeeMakerFactory from being generated
/// (which would collide with this explicit one).
@assistedFactory
abstract class CoffeeMakerFactory {
  @standardCoffeeMaker
  CoffeeMaker create(String name);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  Heater get heater;

  @inject
  CoffeeMakerFactory get coffeeMakerFactory;
}
