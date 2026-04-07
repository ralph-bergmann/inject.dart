import 'package:inject_annotation/inject_annotation.dart';

import 'async_component.inject.dart' as g;

class DatabaseService {}

@module
class DatabaseModule {
  @provides
  @singleton
  @asynchronous
  Future<DatabaseService> provideDatabaseService() async => DatabaseService();
}

@Component([DatabaseModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  Future<DatabaseService> get databaseService;
}
