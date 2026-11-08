import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_provider_synthesized_assisted_dep.inject.dart' as g;

part 'typedef_provider_synthesized_assisted_dep.factory.dart';

// Nothing binds GreetingBuilder, and the constructor of its return type takes
// the function's parameter plus an injectable one, so a typedef provider is
// synthesized: it forwards `name` and injects Clock.

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

class Page {
  @assistedInject
  const Page(this.greetingBuilder, @assisted this.title);

  final GreetingBuilder greetingBuilder;
  final String title;
}

@Component()
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  PageFactory get pageFactory;
}
