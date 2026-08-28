import 'package:inject_annotation/inject_annotation.dart';

import 'subcomponent_factory_value_param_only.inject.dart' as g;

void main() {}

// An explicit @subcomponentFactory whose sole parameter is a value
// parameter (no module parameter at all): `userId` becomes an instance
// binding in the child graph, injectable by any child binding — here the
// module provider `provideApi`.

class RestApiService {
  const RestApiService(this.userId);

  final String userId;
}

@module
class ApiModule {
  @provides
  RestApiService provideApi(String userId) => RestApiService(userId);
}

@Subcomponent([ApiModule])
abstract class ApiSubcomponent {
  RestApiService get apiService;
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
