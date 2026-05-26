import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_multi_named_only.inject.dart' as g;

part 'synthesized_multi_named_only.factory.dart';

class CoffeeMaker {
  @Qualifier(#quick)
  @assistedInject
  CoffeeMaker.quick(@assisted String name);

  @Qualifier(#slow)
  @assistedInject
  CoffeeMaker.slow(@assisted int duration);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeMakerQuickFactory get quickCoffeeMakerFactory;

  @inject
  CoffeeMakerSlowFactory get slowCoffeeMakerFactory;
}
