import 'package:inject_annotation/inject_annotation.dart';

import 'listener_component.inject.dart' as g;

class Heater {}

class Pump {}

class SolarPower {}

class LoggingListener implements ProvisionListener<Object> {
  @override
  void onProvision(Object instance) {}
}

class HeaterListener implements ProvisionListener<Heater> {
  @override
  void onProvision(Heater instance) {}
}

class RawListener implements ProvisionListener {
  @override
  void onProvision(dynamic instance) {}
}

class DynamicListener implements ProvisionListener<dynamic> {
  @override
  void onProvision(dynamic instance) {}
}

const rawListener = Qualifier(#rawListener);
const dynamicListener = Qualifier(#dynamicListener);

@module
class CoffeeModule {
  @provides
  Heater provideHeater() => Heater();

  @provides
  @singleton
  Pump providePump() => Pump();

  @provides
  @asynchronous
  Future<SolarPower> provideSolarPower() async => SolarPower();

  @provides
  @provisionListener
  ProvisionListener<Object> provideLoggingListener() => LoggingListener();

  @provides
  @singleton
  @provisionListener
  ProvisionListener<Heater> provideHeaterListener() => HeaterListener();

  @provides
  @singleton
  @provisionListener
  @rawListener
  ProvisionListener provideRawListener() => RawListener();

  @provides
  @singleton
  @provisionListener
  @dynamicListener
  ProvisionListener<dynamic> provideDynamicListener() => DynamicListener();
}

@Component([CoffeeModule])
abstract class CoffeeComponent {
  static const g.CoffeeComponent$Component Function() create = g.CoffeeComponent$Component.create;

  @inject
  Heater get heater;

  @inject
  Pump get pump;

  @inject
  Future<SolarPower> get solarPower;

  @inject
  ProvisionListener<Heater> get heaterListener;
}
