import 'package:inject_annotation/inject_annotation.dart';

import 'valid_pair.inject.dart' as g;

@inject
class CoffeeService {}

class MyService {
  @assistedInject
  MyService(@assisted this.name, this.coffee);

  final String name;
  final CoffeeService coffee;
}

@assistedFactory
abstract class MyServiceFactory {
  MyService create(String name);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeService get coffeeService;

  @inject
  MyServiceFactory get myServiceFactory;
}
