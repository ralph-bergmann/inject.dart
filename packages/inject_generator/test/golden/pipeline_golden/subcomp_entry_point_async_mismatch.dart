// Golden fixture (error path): subcomponent getters whose `Future` wrapper does
// not match their binding chain.
//
// The child's own async `Foo` satisfies `Foo? get foo` before the parent's sync
// `Foo?`, so the getter must be `Future<Foo?>`. `BarView` reads `Bar?` the same
// way, so its getter must be `Future<BarView>`. `Clock` is bound only by the
// parent and is sync, so `Future<Clock> get clock` must be `Clock`.

import 'package:inject_annotation/inject_annotation.dart';

part 'subcomp_entry_point_async_mismatch.factory.dart';

class Foo {
  const Foo();
}

class Bar {
  const Bar();
}

class BarView {
  @inject
  const BarView(this.bar);

  final Bar? bar;
}

class Clock {
  const Clock();
}

@module
class SessionModule {
  @asynchronous
  @provides
  Future<Foo> provideFoo() async => const Foo();

  @asynchronous
  @provides
  Future<Bar> provideBar() async => const Bar();
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  Foo? get foo;

  BarView get barView;

  Future<Clock> get clock;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @provides
  Foo? provideMaybeFoo() => null;

  @provides
  Bar? provideMaybeBar() => null;

  @provides
  Clock provideClock() => const Clock();
}

@Component([AppModule])
abstract class AppComponent {
  Foo? get maybeFoo;

  Bar? get maybeBar;

  SessionSubcomponentFactory get sessionFactory;
}
