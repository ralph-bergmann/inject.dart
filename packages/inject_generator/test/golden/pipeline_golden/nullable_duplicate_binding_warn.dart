// Warning-path fixture: nullable-duplicate-binding policy = warn.
//
// Module provides both `Config` (non-nullable) and `Config?` (nullable) for
// the same type. With `nullable_duplicate_binding_policy: warn`, both bindings
// are kept, both providers are generated, and a WARNING is emitted.
//
// `Config` is not annotated with @inject — only the module provides it,
// so there is no extraneous duplicate from the injectable path.

import 'package:inject_annotation/inject_annotation.dart';

class Config {
  const Config(this.value);

  final String value;
}

class AppModule {
  @module
  const AppModule();

  @provides
  Config provideConfig() => const Config('default');

  @provides
  Config? provideOptionalConfig() => null;
}

@Component([AppModule])
abstract class AppComponent {
  @inject
  Config get config;

  @inject
  Config? get optionalConfig;
}
