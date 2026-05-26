import 'package:inject_annotation/inject_annotation.dart';

import 'inject_factory_constructor.inject.dart' as g;

@inject
class Heater {}

class CoffeeMaker {
  final Heater heater;

  CoffeeMaker._(this.heater);

  @inject
  factory CoffeeMaker.drip(Heater heater) => CoffeeMaker._(heater);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;
}
