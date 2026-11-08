import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_module_binding_assisted_dep.inject.dart' as g;

part 'typedef_module_binding_assisted_dep.factory.dart';

// A module binds function typedefs that @assistedInject classes inject, so no
// typedef provider may be synthesized. LoadCount is Future-shaped: Future's
// constructor takes a raw function. GreetingBuilder is constructor-shaped: the
// Future shape alone would also be rejected as unbindable, only this one proves
// the binding-key check. OptionalPage injects GreetingBuilder? and is satisfied
// by the non-nullable binding (widening).

typedef LoadCount = Future<int> Function();
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
  LoadCount provideLoadCount() =>
      () async => 42;

  @provides
  GreetingBuilder provideGreetingBuilder() =>
      (name) => Greeting(name, const Clock());
}

class Page {
  @assistedInject
  const Page(this.loadCount, this.greetingBuilder, @assisted this.title);

  final LoadCount loadCount;
  final GreetingBuilder greetingBuilder;
  final String title;
}

class OptionalPage {
  @assistedInject
  const OptionalPage(this.greetingBuilder, @assisted this.title);

  final GreetingBuilder? greetingBuilder;
  final String title;
}

@Component([AppModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function({AppModule? appModule}) create = g.AppComponent$Component.create;

  PageFactory get pageFactory;

  OptionalPageFactory get optionalPageFactory;
}
