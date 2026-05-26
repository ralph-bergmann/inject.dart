import 'package:inject_annotation/inject_annotation.dart';

import 'singleton_providers_component.inject.dart' as g;

class CoffeeMaker {}

class DatabaseService {}

@module
class AppModule {
  @provides
  @singleton
  CoffeeMaker provideCoffeeMaker() => CoffeeMaker();

  @provides
  @singleton
  @asynchronous
  Future<DatabaseService> provideDatabaseService() async => DatabaseService();
}

@Component([AppModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CoffeeMaker get coffeeMaker;

  @inject
  Future<DatabaseService> get databaseService;
}
