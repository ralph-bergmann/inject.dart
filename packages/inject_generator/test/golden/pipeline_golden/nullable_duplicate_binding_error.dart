// Error-path fixture: nullable-duplicate-binding policy = error (default).
//
// Module provides both `Service` (non-nullable) and `Service?` (nullable) for
// the same type. With the default policy (`error`), the validator must emit a
// hard error and suppress the `.inject.dart` output entirely.

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
}
