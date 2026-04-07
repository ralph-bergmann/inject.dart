import 'package:inject_annotation/inject_annotation.dart';

import 'async_module_override.inject.dart' as g;

// Async providers follow the same override semantics as sync providers.
// @Component([AppModule, TestModule]) — TestModule wins.
// _Database$Provider must hold _testModule and call _module.provideDb().
// Async wrapper (_singletonFuture caching) must remain intact.

void main() {}

@Component([AppModule, TestModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  Future<Database> get db;
}

class Database {
  static Future<Database> open(String s) async => Database();
}

@module
class AppModule {
  @provides
  @asynchronous
  @singleton
  Future<Database> provideDb() => Database.open('prod');
}

@module
class TestModule {
  @provides
  @asynchronous
  @singleton
  Future<Database> provideDb() => Database.open('test');
}
