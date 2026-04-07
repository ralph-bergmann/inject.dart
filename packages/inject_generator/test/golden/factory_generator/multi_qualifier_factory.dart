import 'package:inject_annotation/inject_annotation.dart';

import 'multi_qualifier_factory.inject.dart' as g;

const quick = Qualifier(#quick);
const slow = Qualifier(#slow);

@inject
class Heater {}

class CoffeeMaker {
  @quick
  @assistedInject
  CoffeeMaker(this.heater, @assisted this.name) : timeout = 5;

  @slow
  @assistedInject
  CoffeeMaker.detailed(this.heater, @assisted this.name, @assisted this.timeout);

  final Heater heater;
  final String name;
  final int timeout;
}

@assistedFactory
abstract class QuickCoffeeMakerFactory {
  @quick
  CoffeeMaker create(String name);
}

@assistedFactory
abstract class SlowCoffeeMakerFactory {
  @slow
  CoffeeMaker create(String name, int timeout);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  QuickCoffeeMakerFactory get quickCoffeeMakerFactory;

  @inject
  SlowCoffeeMakerFactory get slowCoffeeMakerFactory;
}
