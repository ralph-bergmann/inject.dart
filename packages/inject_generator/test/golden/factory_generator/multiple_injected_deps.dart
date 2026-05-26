import 'package:inject_annotation/inject_annotation.dart';

import 'multiple_injected_deps.inject.dart' as g;

@inject
class Heater {}

@inject
class Grinder {}

class CoffeeMaker {
  @assistedInject
  CoffeeMaker(this.heater, this.grinder, @assisted this.name);

  final Heater heater;
  final Grinder grinder;
  final String name;
}

@assistedFactory
abstract class CoffeeMakerFactory {
  CoffeeMaker create(String name);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeMakerFactory get coffeeMakerFactory;
}
