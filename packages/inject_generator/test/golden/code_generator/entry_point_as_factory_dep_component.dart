import 'package:inject_annotation/inject_annotation.dart';

import 'entry_point_as_factory_dep_component.inject.dart' as g;

class Grinder {
  @inject
  Grinder();
}

class Latte {
  @assistedInject
  Latte(this.grinder, @assisted this.name);

  Grinder grinder;

  String name;
}

@assistedFactory
abstract class LatteFactory {
  Latte create(String name);
}

@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  Grinder get grinder;

  @inject
  LatteFactory get latteFactory;
}
