import 'package:inject_annotation/inject_annotation.dart';

import 'same_qualifier_override.inject.dart' as g;

// Same-qualifier inter-module override: both modules provide `@prod String url()`.
// @Component([AppModule, TestModule]) — TestModule wins because the BindingKey
// (type=String, qualifier='prod') matches and `removeWhere` drops AppModule's entry.
// Guards the intersection of F1 (override) and F4 (qualifier).

const prod = Qualifier(#prod);

void main() {
  final comp = AppComponent.create();
  print(comp.url);
}

@Component([AppModule, TestModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  @prod
  String get url;
}

@module
class AppModule {
  @provides
  @prod
  String url() => 'app-prod-url';
}

@module
class TestModule {
  @provides
  @prod
  String url() => 'test-prod-url';
}
