import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_subcomp_factory_value_param.inject.dart' as g;

part 'typedef_subcomp_factory_value_param.factory.dart';

// SessionView injects GreetingBuilder, whose shape would get a synthesized
// typedef provider. The explicit factory takes it as a value parameter, so the
// value parameter is the binding and no provider is synthesized.

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

class SessionView {
  @assistedInject
  const SessionView(this.greetingBuilder, @assisted this.userId);

  final GreetingBuilder greetingBuilder;
  final String userId;
}

@subcomponent
abstract class SessionSubcomponent {
  SessionViewFactory get sessionViewFactory;
}

@subcomponentFactory
abstract class SessionSubcomponentFactory {
  SessionSubcomponent create(GreetingBuilder greetingBuilder);
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {}

@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  SessionSubcomponentFactory get sessionFactory;
}
