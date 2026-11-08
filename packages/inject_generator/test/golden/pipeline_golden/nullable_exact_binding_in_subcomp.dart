// Golden fixture: exact nullable bindings seen from a subcomponent.
//
// `Clock?` is bound exactly by the parent. `Foo` is bound by the parent while
// `Foo?` is bound by the child, so SessionView reads one from each graph.
// `Timer?` is a nullable value parameter of the subcomponent factory. A child
// module provider, an assisted target and a typedef provider's extra parameters
// read the same three exact bindings. AsyncView reads `Bar?`, which only the
// parent's async `Bar` satisfies, so it becomes async through the parent.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_exact_binding_in_subcomp.factory.dart';

class Clock {
  const Clock();
}

class Foo {
  const Foo();
}

class Timer {
  const Timer();
}

class Bar {
  const Bar();
}

class SessionView {
  @inject
  const SessionView(this.clock, this.foo, this.maybeFoo, this.timer);

  final Clock? clock;
  final Foo foo;
  final Foo? maybeFoo;
  final Timer? timer;
}

class AsyncView {
  @inject
  const AsyncView(this.bar);

  final Bar? bar;
}

typedef ReportBuilder = Report Function(String title);

class Report {
  const Report(this.title, this.clock, this.maybeFoo, this.timer);

  final String title;
  final Clock? clock;
  final Foo? maybeFoo;
  final Timer? timer;
}

class SessionPage {
  @assistedInject
  const SessionPage(this.clock, this.maybeFoo, this.timer, this.reportBuilder, @assisted this.id);

  final Clock? clock;
  final Foo? maybeFoo;
  final Timer? timer;
  final ReportBuilder reportBuilder;
  final int id;
}

@module
class SessionModule {
  @provides
  Foo? provideMaybeFoo() => null;

  @provides
  String provideLabel(Clock? clock, Foo? maybeFoo, Timer? timer) => '$clock $maybeFoo $timer';
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  SessionView get sessionView;

  String get label;

  SessionPageFactory get sessionPageFactory;

  Future<AsyncView> get asyncView;
}

@subcomponentFactory
abstract class SessionSubcomponentFactory {
  SessionSubcomponent create(Timer? timer);
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @provides
  Clock? provideClock() => null;

  @provides
  Foo provideFoo() => const Foo();

  @provides
  @asynchronous
  Future<Bar> provideBar() async => const Bar();
}

@Component([AppModule])
abstract class AppComponent {
  SessionSubcomponentFactory get sessionFactory;
}
