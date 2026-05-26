// Success-path fixture: nullable-duplicate-binding policy = allow.
//
// Module provides both `Service` (non-nullable) and `Service?` (nullable) for
// the same type. With `nullable_duplicate_binding_policy: allow`, both
// bindings are kept and both providers are generated.

import 'package:inject_annotation/inject_annotation.dart';

abstract class Service {
  String call();
}

class ServiceImpl implements Service {
  @inject
  const ServiceImpl();

  @override
  String call() => 'impl';
}

class AppModule {
  @module
  const AppModule();

  @provides
  Service provideService(ServiceImpl impl) => impl;

  @provides
  Service? provideOptionalService(ServiceImpl impl) => impl;
}

@Component([AppModule])
abstract class AppComponent {
  @inject
  Service get service;

  @inject
  Service? get optionalService;
}
