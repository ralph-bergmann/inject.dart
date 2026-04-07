import 'package:inject_annotation/inject_annotation.dart';

import 'sorted_providers_component.inject.dart' as g;

class Zebra {}

class Apple {}

@module
class MyModule {
  @provides
  Zebra provideZebra() => Zebra();

  @provides
  Apple provideApple() => Apple();
}

@Component([MyModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  Zebra get zebra;

  @inject
  Apple get apple;
}
