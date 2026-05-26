import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_multiple_assisted.inject.dart' as g;

part 'synthesized_multiple_assisted.factory.dart';

@inject
class Logger {}

class Greeting {
  @assistedInject
  Greeting(this.logger, @assisted this.name, @assisted this.count);

  final Logger logger;
  final String name;
  final int count;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  GreetingFactory get greetingFactory;
}
