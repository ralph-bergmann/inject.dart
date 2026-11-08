// Golden fixture (error path): `Provider<T>` parameters over a synchronous or a
// missing binding. None of them is about an async chain, so each must keep the
// missing-binding error it has without the async check.

import 'package:inject_annotation/inject_annotation.dart';

part 'provider_parameter_no_async.factory.dart';

class Clock {}

class Logger {}

class MissingForInject {}

class MissingForAssisted {}

class MissingForModule {}

class Report {}

class Audit {}

// `Provider<T>` over a sync binding is supported only at an @inject constructor
// and a typedef provider's extra parameter.
class Page {
  @assistedInject
  Page(Provider<Clock> clock, @assisted String title);
}

class Service {
  @inject
  Service(Provider<MissingForInject> missing);
}

class Dialog {
  @assistedInject
  Dialog(Provider<MissingForAssisted> missing, @assisted String title);
}

@module
class AppModule {
  @provides
  Clock provideClock() => Clock();

  @provides
  Logger provideLogger() => Logger();

  @provides
  Report provideReport(Provider<Logger> logger) => Report();

  @provides
  Audit provideAudit(Provider<MissingForModule> missing) => Audit();
}

@Component([AppModule])
abstract class AppComponent {
  PageFactory get pageFactory;

  Report get report;

  Service get service;

  DialogFactory get dialogFactory;

  Audit get audit;
}
