// Golden fixture: a child that binds both `Foo?` and `Foo`, under the `allow`
// nullable-duplicate policy.
//
// The child's exact `Foo?` is sync and its `Foo` is async. A `Foo?` read uses
// the exact binding, so `maybeFoo` and `Reader` stay sync.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_child_owns_both_forms.factory.dart';

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
  Foo? provideMaybeFoo() => null;

  @asynchronous
  @provides
  Future<Foo> provideFoo() async => const Foo();
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  Foo? get maybeFoo;

  Future<Foo> get foo;

  Reader get reader;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {}

@Component([AppModule])
abstract class AppComponent {
  SessionSubcomponentFactory get sessionFactory;
}
