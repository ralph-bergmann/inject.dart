import 'package:inject_annotation/inject_annotation.dart';

import 'component_with_async_subcomp.inject.dart' as g;

part 'component_with_async_subcomp.factory.dart';

// Async propagation across the component boundary: the parent provides an
// @asynchronous Database; the subcomponent's ApiService consumes it, so the
// subcomponent entry point must be Future<ApiService>. The subcomponent
// factory and both create(...) methods stay synchronous — async-ness lives
// entirely in provider get() signatures and entry points, exactly like
// components.

void main() {}

// ── Subcomponent ─────────────────────────────────────────────────────

class ApiService {
  const ApiService(this.db);

  final Database db;
}

@module
class ApiModule {
  @provides
  ApiService provideApi(Database db) => ApiService(db);
}

@Subcomponent([ApiModule])
abstract class ApiSubcomponent {
  Future<ApiService> get apiService;
}

// ── Parent component ─────────────────────────────────────────────────

class Database {
  static Future<Database> open() async => Database();
}

@Module(subcomponents: [ApiSubcomponent])
class AppModule {
  @provides
  @asynchronous
  @singleton
  Future<Database> provideDb() => Database.open();
}

@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  Future<Database> get db;

  ApiSubcomponentFactory get apiFactory;
}
