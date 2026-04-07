import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_factory_component.inject.dart' as g;

part 'synthesized_factory_component.factory.dart';

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

@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  LatteFactory get latteFactory;
}
