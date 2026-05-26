import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_simple.inject.dart' as g;

part 'synthesized_simple.factory.dart';

@inject
class Heater {}

class CoffeeMaker {
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name);

  final Heater heater;
  final String name;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  Heater get heater;

  @inject
  CoffeeMakerFactory get coffeeMakerFactory;
}
