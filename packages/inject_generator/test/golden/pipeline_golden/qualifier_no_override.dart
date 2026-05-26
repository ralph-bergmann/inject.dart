import 'package:inject_annotation/inject_annotation.dart';

import 'qualifier_no_override.inject.dart' as g;

// Different qualifiers distinguish providers — no override occurs.
// AppModule provides @prod String; TestModule provides @test String.
// Both providers must coexist in the generated component.

const prod = Qualifier(#prod);
const test = Qualifier(#test);

void main() {
  final comp = AppComponent.create();
  print(comp.prodUrl);
  print(comp.testUrl);
}

@Component([AppModule, TestModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  @prod
  String get prodUrl;

  @inject
  @test
  String get testUrl;
}

@module
class AppModule {
  @provides
  @prod
  String url() => 'prod-url';
}

@module
class TestModule {
  @provides
  @test
  String url() => 'test-url';
}
