import 'package:inject_annotation/inject_annotation.dart';

import 'multi_parent_shared_subcomp.inject.dart' as g;

part 'multi_parent_shared_subcomp.factory.dart';

// Regression fixture (story 8.1 code review, High finding): two different
// `@Component`s in the same file each install the *same* `@subcomponent`.
// Each installation is a structurally distinct child graph (a different
// `_parent` type) and must get its own namespaced provider classes — before
// the fix, both installations computed identical child-provider class names,
// so the second installation's providers were silently dropped and its
// `$Subcomponent` class ended up wired to providers built for the *other*
// parent's type (a type mismatch that the analyzer check below would catch).

void main() {}

// ── Subcomponent (installed by both parents below) ──────────────────

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
  Greeter get greeter;
}

// ── First parent component ───────────────────────────────────────────

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

// ── Second parent component, same subcomponent ───────────────────────

@Module(subcomponents: [GreeterSubcomponent])
class OtherAppModule {
  @provides
  String provideLabel() => 'other';
}

@Component([OtherAppModule])
abstract class OtherAppComponent {
  static const create = g.OtherAppComponent$Component.create;

  String get label;

  GreeterSubcomponentFactory get greeterFactory;
}
