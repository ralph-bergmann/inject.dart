import 'package:inject_annotation/inject_annotation.dart';

import 'component_with_subcomp_encapsulation.inject.dart' as g;

part 'component_with_subcomp_encapsulation.factory.dart';

// Canonical encapsulation scenario: the HTTP client lives inside a
// subcomponent and is invisible to the parent; only the RestApiService is
// re-exported through a parent module provider that consumes the
// subcomponent's factory. The child binding is qualified so the parent
// re-export (unqualified) does not collide with it.

void main() {}

const internal = Qualifier(#internal);

// ── Subcomponent: private HTTP stack ─────────────────────────────────

class HttpClient {
  const HttpClient();
}

class RestApiService {
  const RestApiService(this.client, this.db);

  final HttpClient client;
  final Database db;
}

@module
class HttpModule {
  @provides
  @singleton
  HttpClient provideClient() => const HttpClient();

  @provides
  @internal
  RestApiService provideApi(HttpClient client, Database db) => RestApiService(client, db);
}

@Subcomponent([HttpModule])
abstract class HttpSubcomponent {
  @internal
  RestApiService get apiService;
}

// ── Parent component ─────────────────────────────────────────────────

@inject
@singleton
class Database {
  const Database();
}

@Module(subcomponents: [HttpSubcomponent])
class NetworkModule {
  @provides
  @singleton
  RestApiService provideApi(HttpSubcomponentFactory factory) => factory.create().apiService;
}

@Component([NetworkModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  Database get db;

  RestApiService get api;
}
