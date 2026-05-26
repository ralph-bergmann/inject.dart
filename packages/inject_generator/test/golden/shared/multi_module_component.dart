import 'package:inject_annotation/inject_annotation.dart';

import 'multi_module_component.inject.dart' as g;

class Heater {}

class Pump {}

@module
class HeaterModule {
  @provides
  Heater provideHeater() => Heater();
}

@module
class PumpModule {
  @provides
  Pump providePump() => Pump();
}

@Component([HeaterModule, PumpModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  Heater get heater;

  @inject
  Pump get pump;
}
