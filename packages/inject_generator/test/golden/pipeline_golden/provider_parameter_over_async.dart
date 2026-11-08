// Golden fixture (error path): `Provider<T>` parameters over an asynchronous
// binding chain. A `Provider<T>` must return `T` synchronously, so every shape
// below must report exactly one error at its parameter.

import 'package:inject_annotation/inject_annotation.dart';

part 'provider_parameter_over_async.factory.dart';

// An @inject constructor over a directly async binding.
class C {}

class A {
  @inject
  A(Provider<C> c);
}

// An @inject constructor over a transitively async binding.
class D {}

class Repo {
  @inject
  Repo(D d);
}

class B {
  @inject
  B(Provider<Repo> r);
}

// An @assistedInject constructor keeps the wrapper in its binding key.
class E {}

class Page {
  @assistedInject
  Page(Provider<E> e, @assisted String t);
}

// A module provider method keeps the wrapper in its binding key too.
class G {}

class H {}

// A typedef provider's extra parameter.
class I {}

class Item {
  Item(String name, Provider<I> i);
}

typedef ListFactory = Item Function(String name);

class ListPage {
  @assistedInject
  ListPage(ListFactory f, @assisted String t);
}

// A nullable value type that only the non-nullable async binding satisfies.
class K {}

class J {
  @inject
  J(Provider<K?> k);
}

// A subcomponent class over the parent's async binding.
class M {}

class L {
  @inject
  L(Provider<M> m);
}

// A qualified parameter over a binding with the same qualifier.
const prod = Qualifier(#prod);

class N {}

class O {}

// `@inject` classes that only a kept `Provider` wrapper reaches.
class RepoForPage {
  @inject
  RepoForPage(D d);
}

class RepoPage {
  @assistedInject
  RepoPage(Provider<RepoForPage> r, @assisted String t);
}

class RepoForModule {
  @inject
  RepoForModule(D d);
}

class P {}

// A generic class behind a typedef provider: the fix names the type variable.
class Q {}

class Box<T> {
  Box(String name, Provider<T> value);
}

typedef BoxFactory = Box<Q> Function(String name);

class BoxPage {
  @assistedInject
  BoxPage(BoxFactory f, @assisted String t);
}

// Plain parameters of an assisted factory: `create` cannot wait for them.
class PlainPage {
  @assistedInject
  PlainPage(C c, @assisted String t);
}

class ChainPage {
  @assistedInject
  ChainPage(Repo r, @assisted String t);
}

// A typedef provider's plain extra parameter: the closure cannot wait for it.
class PlainItem {
  PlainItem(String name, C c);
}

typedef PlainItemFactory = PlainItem Function(String name);

class PlainItemPage {
  @assistedInject
  PlainItemPage(PlainItemFactory f, @assisted String t);
}

// `Provider<Future<T>>` over an `@asynchronous T`: it only fits a raw `Future<T>` binding.
class FutureA {
  @inject
  FutureA(Provider<Future<C>> c);
}

class RepoForFuture {
  @inject
  RepoForFuture(D d);
}

class FutureB {
  @inject
  FutureB(Provider<Future<RepoForFuture>> r);
}

class FuturePage {
  @assistedInject
  FuturePage(Provider<Future<C>> c, @assisted String t);
}

class FutureItem {
  FutureItem(String name, Provider<Future<C>> c);
}

typedef FutureItemFactory = FutureItem Function(String name);

class FutureItemPage {
  @assistedInject
  FutureItemPage(FutureItemFactory f, @assisted String t);
}

class FutureModuleValue {}

// A subcomponent's module provider method over the parent's async binding.
class S {}

// A subcomponent's assisted factory over the parent's async binding.
class SessionPage {
  @assistedInject
  SessionPage(M m, @assisted String t);
}

@module
class SessionModule {
  @provides
  S provideS(Provider<M> m) => S();
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  Future<L> get l;

  S get s;

  SessionPageFactory get sessionPage;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @asynchronous
  @provides
  Future<C> provideC() async => C();

  @asynchronous
  @provides
  Future<D> provideD() async => D();

  @asynchronous
  @provides
  Future<E> provideE() async => E();

  @provides
  G provideG(Provider<H> h) => G();

  @asynchronous
  @provides
  Future<H> provideH() async => H();

  @asynchronous
  @provides
  Future<I> provideI() async => I();

  @asynchronous
  @provides
  Future<K> provideK() async => K();

  @asynchronous
  @provides
  Future<M> provideM() async => M();

  @provides
  N provideN(@prod Provider<O> o) => N();

  @prod
  @asynchronous
  @provides
  Future<O> provideO() async => O();

  @provides
  P provideP(Provider<RepoForModule> r) => P();

  @asynchronous
  @provides
  Future<Q> provideQ() async => Q();

  @provides
  FutureModuleValue provideFutureModuleValue(Provider<Future<C>> c) => FutureModuleValue();
}

@Component([AppModule])
abstract class AppComponent {
  Future<A> get a;

  Future<B> get b;

  PageFactory get f;

  G get g;

  ListFactory get l;

  ListPageFactory get listPage;

  Future<J> get j;

  N get n;

  RepoPageFactory get repoPage;

  P get p;

  BoxPageFactory get boxPage;

  PlainPageFactory get plainPage;

  ChainPageFactory get chainPage;

  PlainItemPageFactory get plainItemPage;

  FutureA get futureA;

  FutureB get futureB;

  FuturePageFactory get futurePage;

  FutureItemPageFactory get futureItemPage;

  FutureModuleValue get futureModuleValue;

  SessionSubcomponentFactory get sessionFactory;
}
