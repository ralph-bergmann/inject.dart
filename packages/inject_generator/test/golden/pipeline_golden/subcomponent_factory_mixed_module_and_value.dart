import 'package:inject_annotation/inject_annotation.dart';

import 'subcomponent_factory_mixed_module_and_value.inject.dart' as g;

void main() {}

// A factory method that mixes a module parameter (following the existing
// declared-modules rules — required here, since HttpModule has no default
// constructor) with a qualified value parameter. Both compose independently.

const apiKey = Qualifier(#apiKey);

class RestApiService {
  const RestApiService(this.baseUrl, this.apiKey);

  final String baseUrl;
  final String apiKey;
}

@module
class HttpModule {
  const HttpModule(this.baseUrl);

  final String baseUrl;

  @provides
  RestApiService provideApi(@apiKey String key) => RestApiService(baseUrl, key);
}

@Subcomponent([HttpModule])
abstract class ApiSubcomponent {
  RestApiService get apiService;
}

@subcomponentFactory
abstract class ApiSubcomponentFactory {
  ApiSubcomponent create(HttpModule module, @apiKey String key);
}

@Module(subcomponents: [ApiSubcomponent])
class NetworkModule {}

@Component([NetworkModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  ApiSubcomponentFactory get apiFactory;
}
