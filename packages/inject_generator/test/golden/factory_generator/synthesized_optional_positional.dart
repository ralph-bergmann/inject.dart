import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_optional_positional.inject.dart' as g;

part 'synthesized_optional_positional.factory.dart';

class Heater {
  @inject
  Heater();
}

class Tea {
  @assistedInject
  Tea(this.heater, @assisted this.name, [@assisted this.suffix]);

  final Heater heater;
  final String name;
  final String? suffix;
}

@Component()
abstract class TeaShop {
  static const g.TeaShop$Component Function() create = g.TeaShop$Component.create;

  @inject
  TeaFactory get teaFactory;
}
