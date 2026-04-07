import 'package:inject_annotation/inject_annotation.dart';

import 'minimal_component.inject.dart' as g;

@inject
class CoffeeMaker {
  CoffeeMaker();
}

@component
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;
}
