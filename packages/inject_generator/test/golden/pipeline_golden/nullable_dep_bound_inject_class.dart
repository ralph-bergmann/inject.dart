// Golden fixture: `Clock?` dependencies when a module binds `Clock` and `Clock`
// also has an @inject constructor.
//
// The module binding satisfies every read: a module provider, an assisted
// target, a discovered @inject class and a class in a subcomponent. Clock must
// not be discovered as an injectable, so no duplicate binding is reported.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_dep_bound_inject_class.factory.dart';

class Clock {
  @inject
  const Clock();
}

class Dashboard {
  @inject
  const Dashboard(this.clock);

  final Clock? clock;
}

class Page {
  @assistedInject
  const Page(this.clock, @assisted this.id);

  final Clock? clock;
  final int id;
}

class SessionView {
  @inject
  const SessionView(this.clock);

  final Clock? clock;
}

@subcomponent
abstract class SessionSubcomponent {
  SessionView get sessionView;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @provides
  Clock provideClock() => const Clock();

  @provides
  String provideLabel(Clock? clock) => '$clock';
}

@Component([AppModule])
abstract class AppComponent {
  String get label;

  Dashboard get dashboard;

  PageFactory get pageFactory;

  SessionSubcomponentFactory get sessionFactory;
}
