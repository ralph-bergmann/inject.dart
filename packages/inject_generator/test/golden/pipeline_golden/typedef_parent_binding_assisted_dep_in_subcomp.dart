import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_parent_binding_assisted_dep_in_subcomp.inject.dart' as g;

part 'typedef_parent_binding_assisted_dep_in_subcomp.factory.dart';

// The child's SessionView injects three function typedefs the parent provides:
// LoadCount and GreetingBuilder through a module, BadgeBuilder through the
// parent's own synthesized typedef provider (Dashboard injects it). The child
// must synthesize none of them and resolve all three through the parent.

typedef LoadCount = Future<int> Function();
typedef GreetingBuilder = Greeting Function(String name);
typedef BadgeBuilder = Badge Function(String label);

class Clock {
  @inject
  const Clock();
}

class Greeting {
  const Greeting(this.name, this.clock);

  final String name;
  final Clock clock;
}

class Badge {
  const Badge(this.label, this.clock);

  final String label;
  final Clock clock;
}

// ── Parent component ─────────────────────────────────────────────────

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @provides
  LoadCount provideLoadCount() =>
      () async => 42;

  @provides
  GreetingBuilder provideGreetingBuilder() =>
      (name) => Greeting(name, const Clock());
}

class Dashboard {
  @assistedInject
  const Dashboard(this.badgeBuilder, @assisted this.title);

  final BadgeBuilder badgeBuilder;
  final String title;
}

@Component([AppModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function({AppModule? appModule}) create = g.AppComponent$Component.create;

  DashboardFactory get dashboardFactory;

  SessionSubcomponentFactory get sessionSubcomponentFactory;
}

// ── Subcomponent ─────────────────────────────────────────────────────

class SessionView {
  @assistedInject
  const SessionView(this.loadCount, this.greetingBuilder, this.badgeBuilder, @assisted this.userId);

  final LoadCount loadCount;
  final GreetingBuilder greetingBuilder;
  final BadgeBuilder badgeBuilder;
  final String userId;
}

@subcomponent
abstract class SessionSubcomponent {
  SessionViewFactory get sessionViewFactory;
}
