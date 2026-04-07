import 'package:inject_annotation/inject_annotation.dart';

import 'named_constructor.inject.dart' as g;

@inject
class Heater {}

class CoffeeMaker {
  @assistedInject
  CoffeeMaker.withName(this.heater, @assisted this.name);

  final Heater heater;
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
