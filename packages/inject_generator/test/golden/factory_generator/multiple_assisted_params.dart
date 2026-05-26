import 'package:inject_annotation/inject_annotation.dart';

import 'multiple_assisted_params.inject.dart' as g;

@inject
class Logger {}

class Greeting {
  @assistedInject
  Greeting(this.logger, @assisted this.name, @assisted this.count);

  final Logger logger;
  final String name;
  final int count;
}

@assistedFactory
abstract class GreetingFactory {
  Greeting create(String name, int count);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  GreetingFactory get greetingFactory;
}
