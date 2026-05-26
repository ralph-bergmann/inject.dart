import 'package:inject_annotation/inject_annotation.dart';

import 'nested_synthesized_factory_component.inject.dart' as g;

part 'nested_synthesized_factory_component.factory.dart';

class Grinder {
  @inject
  Grinder();
}

class Latte {
  @assistedInject
  Latte(this.grinder, @assisted this.name);

  final Grinder grinder;
  final String name;
}

class CoffeeApp {
  @assistedInject
  CoffeeApp(this.latteFactory, @assisted this.id);

  final LatteFactory latteFactory;
  final int id;
}

@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  CoffeeAppFactory get coffeeAppFactory;
}
