import 'package:inject_annotation/inject_annotation.dart';

import 'sync_subcomp_no_parent_deps.inject.dart' as g;

part 'sync_subcomp_no_parent_deps.factory.dart';

// A fully self-contained synchronous subcomponent: no parent bindings are
// consumed, the module carries a runtime value through its constructor
// (required create parameter), and the child singleton lives once per
// subcomponent instance.

void main() {}

// ── Subcomponent ─────────────────────────────────────────────────────

class Greeter {
  const Greeter(this.greeting);

  final String greeting;
}

@module
class GreeterModule {
  const GreeterModule(this.greeting);

  final String greeting;

  @provides
  @singleton
  Greeter provideGreeter() => Greeter(greeting);
}

@Subcomponent([GreeterModule])
abstract class GreeterSubcomponent {
  // AC-6: the `static const create = <Name>$Subcomponent.create` pattern
  // works symmetrically to `@Component` — a constructor tear-off referring
  // to the generated implementation's factory constructor. Not the
  // recommended entry point for callers (use the generated
  // `GreeterSubcomponentFactory` instead, see `AppComponent.greeterFactory`
  // below), but it must exist and type-check.
  static const create = g.GreeterSubcomponent$Subcomponent.create;

  Greeter get greeter;
}

// ── Parent component ─────────────────────────────────────────────────

@Module(subcomponents: [GreeterSubcomponent])
class AppModule {
  @provides
  int provideAnswer() => 42;
}

@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  int get answer;

  GreeterSubcomponentFactory get greeterFactory;
}
