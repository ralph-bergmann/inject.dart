// Golden fixture: nullable-duplicate-binding policy = allow, with an @inject
// class and an assisted target each reading both bindings. `Service` and
// `Service?` stay two fields fed by two distinct providers.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_duplicate_binding_allow_consumed.factory.dart';

class Service {
  const Service();
}

class Consumer {
  @inject
  const Consumer(this.service, this.optionalService);

  final Service service;
  final Service? optionalService;
}

class Page {
  @assistedInject
  const Page(this.service, this.optionalService, @assisted this.id);

  final Service service;
  final Service? optionalService;
  final int id;
}

@module
class AppModule {
  @provides
  Service provideService() => const Service();

  @provides
  Service? provideOptionalService() => null;
}

@Component([AppModule])
abstract class AppComponent {
  Consumer get consumer;

  PageFactory get pageFactory;
}
