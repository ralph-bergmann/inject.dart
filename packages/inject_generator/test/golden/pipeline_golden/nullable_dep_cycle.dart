// Golden fixture (error path): a dependency cycle that closes through `Foo?`.
//
// `Foo?` has no binding of its own, so `provideBar` reads the `Foo` binding and
// the graph has the cycle `Foo → Bar → Foo`.

import 'package:inject_annotation/inject_annotation.dart';

class Foo {
  const Foo();
}

class Bar {
  const Bar();
}

@module
class AppModule {
  @provides
  Foo provideFoo(Bar bar) => const Foo();

  @provides
  Bar provideBar(Foo? foo) => const Bar();
}

@Component([AppModule])
abstract class AppComponent {
  Foo get foo;
}
