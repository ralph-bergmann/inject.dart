// Golden fixture: a parent class reads `T?` through the parent's `T` while the
// child binds an exact `T?`.
//
// The parent's class follows the parent's `T`, so a child getter over that class
// has the parent's async status. A child read of `T?` follows the child's exact
// binding.
//
// The child's exact binding is sync over the parent's async AsyncFoo, and async
// over the parent's sync SyncFoo.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_parent_reader_beside_child_exact.factory.dart';

class AsyncFoo {
  const AsyncFoo();
}

class SyncFoo {
  const SyncFoo();
}

class AsyncFooReader {
  @inject
  const AsyncFooReader(this.foo);

  final AsyncFoo? foo;
}

class SyncFooReader {
  @inject
  const SyncFooReader(this.foo);

  final SyncFoo? foo;
}

@module
class SessionModule {
  @provides
  AsyncFoo? provideChildAsyncFoo() => null;

  @asynchronous
  @provides
  Future<SyncFoo?> provideChildSyncFoo() async => null;
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  Future<AsyncFooReader> get asyncFooReader;

  SyncFooReader get syncFooReader;

  AsyncFoo? get asyncFoo;

  Future<SyncFoo?> get syncFoo;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @asynchronous
  @provides
  Future<AsyncFoo> provideAsyncFoo() async => const AsyncFoo();

  @provides
  SyncFoo provideSyncFoo() => const SyncFoo();
}

@Component([AppModule])
abstract class AppComponent {
  Future<AsyncFooReader> get asyncFooReader;

  SyncFooReader get syncFooReader;

  SessionSubcomponentFactory get sessionFactory;
}
