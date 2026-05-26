import 'package:inject_annotation/inject_annotation.dart';

import 'mixed_inject_and_assisted.inject.dart' as g;

part 'mixed_inject_and_assisted.factory.dart';

@inject
class Heater {}

/// A class that uses both @inject (standard DI) and @assistedInject
/// (factory-created) on different constructors of the same class.
class CoffeeMaker {
  @inject
  CoffeeMaker(this.heater) : blend = 'blend';

  @assistedInject
  CoffeeMaker.custom(this.heater, @assisted this.blend);

  final Heater heater;
  final String blend;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  Heater get heater;

  @inject
  CoffeeMakerFactory get coffeeMakerFactory;
}
