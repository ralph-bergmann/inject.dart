import 'package:inject_annotation/inject_annotation.dart';

import 'sync_async_mixed_override.inject.dart' as g;

// F6 closure: a single component with BOTH sync and async overrides at once.
// @Component([AppModule, TestModule]) — TestModule wins for `String message()`
// AND for `@asynchronous Future<Database> provideDb()`. Proves the override loop
// in `_buildBindings()` does not differentiate sync from async paths and that
// both `_String$Provider` and `_Database$Provider` reference _testModule.

void main() {}

@Component([AppModule, TestModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  String get message;

  @inject
  Future<Database> get db;
}

class Database {
  static Future<Database> open(String s) async => Database();
}

@module
class AppModule {
  @provides
  String message() => 'app';

  @provides
  @asynchronous
  @singleton
  Future<Database> provideDb() => Database.open('app');
}

@module
class TestModule {
  @provides
  String message() => 'test';

  @provides
  @asynchronous
  @singleton
  Future<Database> provideDb() => Database.open('test');
}
