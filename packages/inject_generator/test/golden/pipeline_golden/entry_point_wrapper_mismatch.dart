// Golden fixture (error path): getters whose `Future` wrapper does not match
// whether their binding chain is async.
//
// Every getter reads its own type, so nothing aggregates. `D?`, `E?` and `F?`
// are satisfied by nullable widening.

import 'package:inject_annotation/inject_annotation.dart';

class A {
  const A();
}

class B {
  const B();
}

class C {
  const C();
}

class D {
  const D();
}

class E {
  const E();
}

class F {
  const F();
}

@module
class AppModule {
  @provides
  A provideA() => const A();

  @provides
  B provideB() => const B();

  @asynchronous
  @provides
  Future<C> provideC() async => const C();

  @provides
  D provideD() => const D();

  @asynchronous
  @provides
  Future<E> provideE() async => const E();

  @provides
  F provideF() => const F();
}

@Component([AppModule])
abstract class AppComponent {
  Future<A> get a;

  Provider<Future<B>> get b;

  Provider<C> get c;

  Future<D?> get d;

  Provider<E?> get e;

  Provider<Future<F?>> get f;
}
