import 'package:inject_annotation/inject_annotation.dart';

import 'async_dep_component.inject.dart' as g;

class Database {}

class Api {}

class Service {
  @inject
  Service(this.database, this.api);

  final Database database;
  final Future<Api> api;
}

@module
class AppModule {
  @provides
  @asynchronous
  Future<Database> provideDatabase() async => Database();

  @provides
  Future<Api> provideApi() async => Api();
}

@Component([AppModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function({AppModule? appModule}) create = g.AppComponent$Component.create;

  @inject
  Future<Service> get service;
}
