// Golden fixture: a @subcomponentFactory value parameter whose type also has an
// @inject constructor. The value parameter is the binding, so SessionView reads
// it and Clock is not discovered as an injectable.

import 'package:inject_annotation/inject_annotation.dart';

class Clock {
  @inject
  const Clock();
}

class SessionView {
  @inject
  const SessionView(this.clock);

  final Clock clock;
}

@subcomponent
abstract class SessionSubcomponent {
  SessionView get sessionView;
}

@subcomponentFactory
abstract class SessionSubcomponentFactory {
  SessionSubcomponent create(Clock clock);
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {}

@Component([AppModule])
abstract class AppComponent {
  SessionSubcomponentFactory get sessionFactory;
}
