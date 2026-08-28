import 'package:inject_annotation/inject_annotation.dart';

import 'subcomp_provision_listener_scope.inject.dart' as g;

part 'subcomp_provision_listener_scope.factory.dart';

// Regression fixture (story 8.1 code review, Low finding): `@provisionListener`
// is component-local and must not cross the parent/child boundary. The
// parent's listener observes only parent provisions; the child's own
// listener observes only child provisions. The generated code must not wire
// the parent listener into the child's provider constructors, or vice versa.

void main() {}

// ── Parent ────────────────────────────────────────────────────────────

class ParentThing {
  const ParentThing();
}

class ParentListener implements ProvisionListener<ParentThing> {
  @override
  void onProvision(ParentThing instance) {}
}

@Module(subcomponents: [ChildSubcomponent])
class ParentModule {
  @provides
  @singleton
  ParentThing provideParentThing() => const ParentThing();

  @provides
  @singleton
  @provisionListener
  ParentListener provideParentListener() => ParentListener();
}

@Component([ParentModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  ParentThing get parentThing;

  ChildSubcomponentFactory get childFactory;
}

// ── Child (subcomponent) ─────────────────────────────────────────────

class ChildThing {
  const ChildThing();
}

class ChildListener implements ProvisionListener<ChildThing> {
  @override
  void onProvision(ChildThing instance) {}
}

@module
class ChildModule {
  @provides
  @singleton
  ChildThing provideChildThing() => const ChildThing();

  @provides
  @singleton
  @provisionListener
  ChildListener provideChildListener() => ChildListener();
}

@Subcomponent([ChildModule])
abstract class ChildSubcomponent {
  ChildThing get childThing;
}
