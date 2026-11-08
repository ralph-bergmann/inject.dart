// Golden fixture: a child's own `T` shadows the parent's exact `T?`.
//
// The resolver reads `T?` from the child's `T` before the parent's `T?`, so the
// child's read follows the child's async status. The parent's own readers keep
// reading the parent's exact `T?`.
//
// ChildSyncValue and ChildAsyncValue are read by child getters. ChildAsyncDep
// and ChildSyncDep are read by child classes. SharedDep is read by a parent
// class that the child exposes unchanged.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_child_shadows_parent.factory.dart';

class ChildSyncValue {
  const ChildSyncValue();
}

class ChildAsyncValue {
  const ChildAsyncValue();
}

class ChildAsyncDep {
  const ChildAsyncDep();
}

class ChildSyncDep {
  const ChildSyncDep();
}

class SharedDep {
  const SharedDep();
}

class AsyncView {
  @inject
  const AsyncView(this.dep);

  final ChildAsyncDep? dep;
}

class SyncView {
  @inject
  const SyncView(this.dep);

  final ChildSyncDep? dep;
}

class ParentReader {
  @inject
  const ParentReader(this.dep);

  final SharedDep? dep;
}

@module
class SessionModule {
  @provides
  ChildSyncValue provideChildSyncValue() => const ChildSyncValue();

  @asynchronous
  @provides
  Future<ChildAsyncValue> provideChildAsyncValue() async => const ChildAsyncValue();

  @asynchronous
  @provides
  Future<ChildAsyncDep> provideChildAsyncDep() async => const ChildAsyncDep();

  @provides
  ChildSyncDep provideChildSyncDep() => const ChildSyncDep();

  @asynchronous
  @provides
  Future<SharedDep> provideChildSharedDep() async => const SharedDep();
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  ChildSyncValue? get childSyncValue;

  Future<ChildAsyncValue?> get childAsyncValue;

  Future<AsyncView> get asyncView;

  SyncView get syncView;

  ParentReader get parentReader;

  Future<SharedDep> get sharedDep;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @asynchronous
  @provides
  Future<ChildSyncValue?> provideParentSyncValue() async => null;

  @provides
  ChildAsyncValue? provideParentAsyncValue() => null;

  @provides
  ChildAsyncDep? provideParentAsyncDep() => null;

  @asynchronous
  @provides
  Future<ChildSyncDep?> provideParentSyncDep() async => null;

  @provides
  SharedDep? provideParentSharedDep() => null;
}

@Component([AppModule])
abstract class AppComponent {
  Future<ChildSyncValue?> get parentSyncValue;

  ChildAsyncValue? get parentAsyncValue;

  ChildAsyncDep? get parentAsyncDep;

  Future<ChildSyncDep?> get parentSyncDep;

  SharedDep? get parentSharedDep;

  ParentReader get parentReader;

  SessionSubcomponentFactory get sessionFactory;
}
