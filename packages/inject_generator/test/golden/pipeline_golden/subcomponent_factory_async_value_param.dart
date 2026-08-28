import 'package:inject_annotation/inject_annotation.dart';

import 'subcomponent_factory_async_value_param.inject.dart' as g;

void main() {}

// A subcomponent whose graph mixes an async module-provided binding with a
// synchronous `@subcomponentFactory` value parameter: `create(...)` itself
// stays synchronous (story 8-1's architecture decision), while the entry
// point that transitively depends on the async binding surfaces as a
// `Future<T>`, exactly as the existing async-propagation machinery already
// does across a component/subcomponent boundary.

class HttpClient {
  const HttpClient();
}

@module
class AsyncApiModule {
  @provides
  @asynchronous
  Future<HttpClient> provideClient() async => const HttpClient();
}

@inject
class RestApiService {
  const RestApiService(this.client, this.userId);

  final HttpClient client;
  final String userId;
}

@Subcomponent([AsyncApiModule])
abstract class ApiSubcomponent {
  Future<RestApiService> get apiService;
}

@subcomponentFactory
abstract class ApiSubcomponentFactory {
  ApiSubcomponent create(String userId);
}

@Module(subcomponents: [ApiSubcomponent])
class NetworkModule {}

@Component([NetworkModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  ApiSubcomponentFactory get apiFactory;
}
