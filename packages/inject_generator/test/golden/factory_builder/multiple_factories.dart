import 'package:inject_annotation/inject_annotation.dart';

import 'multiple_factories.inject.dart' as g;

@inject
class Heater {}

@inject
class Grinder {}

@assistedFactory
abstract class PourOverFactory {
  PourOver create({required int grams, required String origin});
}

class PourOver {
  @assistedInject
  PourOver(this.heater, {@assisted required this.origin, @assisted required this.grams});

  final Heater heater;
  final String origin;
  final int grams;
}

@assistedFactory
abstract class EspressoFactory {
  Espresso create(String roast);
}

class Espresso {
  @assistedInject
  Espresso(this.grinder, @assisted this.roast);

  final Grinder grinder;
  final String roast;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  Heater get heater;

  @inject
  Grinder get grinder;

  @inject
  PourOverFactory get pourOverFactory;

  @inject
  EspressoFactory get espressoFactory;
}
