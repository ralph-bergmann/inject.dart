import 'package:inject_annotation/inject_annotation.dart';

import 'subcomp_test_parent_override.inject.dart' as g;

part 'subcomp_test_parent_override.factory.dart';

// Testing seam for subcomponents: the test component appends a fake module
// (later modules win) while reusing the unchanged subcomponents-installing
// module. The subcomponent regenerates under the test component and inherits
// the fake — Database resolves to FakeDbModule for both the parent entry
// point AND the child graph.

void main() {}

// ── Production bindings ──────────────────────────────────────────────

abstract class Database {
  String get name;
}

class RealDb implements Database {
  const RealDb();

  @override
  String get name => 'real';
}

class FakeDb implements Database {
  const FakeDb();

  @override
  String get name => 'fake';
}

@module
class DbModule {
  @provides
  @singleton
  Database provideDb() => const RealDb();
}

@module
class FakeDbModule {
  @provides
  @singleton
  Database provideDb() => const FakeDb();
}

// ── Subcomponent consuming the parent binding ────────────────────────

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
  ApiService get apiService;
}

@Module(subcomponents: [ApiSubcomponent])
class SubcomponentsModule {}

// ── Test component: appends the fake module, reuses SubcomponentsModule ──

@Component([DbModule, FakeDbModule, SubcomponentsModule])
abstract class TestAppComponent {
  static const create = g.TestAppComponent$Component.create;

  Database get db;

  ApiSubcomponentFactory get apiFactory;
}
