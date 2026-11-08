import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_qualified_binding_assisted_dep.inject.dart' as g;

part 'typedef_qualified_binding_assisted_dep.factory.dart';

// The qualifier is part of the binding key. QualifiedPage gets the module's
// `@primary GreetingBuilder`; UnqualifiedPage asks for the unqualified key,
// which nothing binds, so it gets a synthesized typedef provider beside it.

const primary = Qualifier(#primary);

typedef GreetingBuilder = Greeting Function(String name);

class Clock {
  @inject
  const Clock();
}

class Greeting {
  const Greeting(this.name, this.clock);

  final String name;
  final Clock clock;
}

@module
class AppModule {
  @provides
  @primary
  GreetingBuilder providePrimaryGreetingBuilder() =>
      (name) => Greeting(name, const Clock());
}

class QualifiedPage {
  @assistedInject
  const QualifiedPage(@primary this.greetingBuilder, @assisted this.title);

  final GreetingBuilder greetingBuilder;
  final String title;
}

class UnqualifiedPage {
  @assistedInject
  const UnqualifiedPage(this.greetingBuilder, @assisted this.title);

  final GreetingBuilder greetingBuilder;
  final String title;
}

@Component([AppModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function({AppModule? appModule}) create = g.AppComponent$Component.create;

  QualifiedPageFactory get qualifiedPageFactory;

  UnqualifiedPageFactory get unqualifiedPageFactory;
}
