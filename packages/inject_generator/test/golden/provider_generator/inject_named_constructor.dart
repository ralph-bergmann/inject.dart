import 'package:inject_annotation/inject_annotation.dart';

import 'inject_named_constructor.inject.dart' as g;

@inject
class Heater {}

class CoffeeMaker {
  @inject
  CoffeeMaker.french(this.heater);

  final Heater heater;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;
}
