import 'package:inject_annotation/inject_annotation.dart';

import 'subcomp_installed_via_include.inject.dart' as g;

part 'subcomp_installed_via_include.factory.dart';

// Installation through an umbrella include: NetworkModule both provides the
// parent Database binding and installs HttpSubcomponent, but the component
// lists ONLY UmbrellaModule (itself without `subcomponents:`), which reaches
// NetworkModule solely through `@Module(includes: [...])`. Module expansion
// runs before subcomponent discovery, so the installation must behave
// exactly as if NetworkModule were listed directly: the synthesized factory
// binding is exposed as an entry point and the child graph consumes the
// parent Database through the parent reference.

void main() {}

// ── Subcomponent ─────────────────────────────────────────────────────

class ApiService {
  const ApiService(this.db);

  final Database db;
}

@module
class HttpModule {
  @provides
  ApiService provideApi(Database db) => ApiService(db);
}

@Subcomponent([HttpModule])
abstract class HttpSubcomponent {
  ApiService get apiService;
}

// ── Parent component ─────────────────────────────────────────────────

class Database {
  const Database();
}

@Module(subcomponents: [HttpSubcomponent])
class NetworkModule {
  @provides
  @singleton
  Database provideDatabase() => const Database();
}

@Module(includes: [NetworkModule])
class UmbrellaModule {}

@Component([UmbrellaModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  Database get db;

  HttpSubcomponentFactory get httpFactory;
}
