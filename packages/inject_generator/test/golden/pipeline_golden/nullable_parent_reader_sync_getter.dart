// Golden fixture (error path): a synchronous child getter over a parent class
// that reads `Foo?` through the parent's async `Foo`, beside a child's sync
// exact `Foo?`.
//
// The parent's class follows the parent's `Foo`, so the getter must be declared
// `Future<Reader>`. The build reports the usual sync-getter error at the getter.

import 'package:inject_annotation/inject_annotation.dart';

class Foo {
  const Foo();
}

class Reader {
  @inject
  const Reader(this.foo);

  final Foo? foo;
}

@module
class SessionModule {
  @provides
  Foo? provideChildFoo() => null;
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  Reader get reader;
}

@subcomponentFactory
abstract class SessionSubcomponentFactory {
  SessionSubcomponent create();
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @asynchronous
  @provides
  Future<Foo> provideFoo() async => const Foo();
}

@Component([AppModule])
abstract class AppComponent {
  Future<Reader> get reader;

  SessionSubcomponentFactory get sessionFactory;
}
