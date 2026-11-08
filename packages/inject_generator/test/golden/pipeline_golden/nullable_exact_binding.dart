// Golden fixture: an exact `@provides Clock?` binding read as `Clock?` by an
// @inject class, a module provider, an assisted target and the extra parameter
// of a typedef provider. Each read must use `_ClockNullable$Provider`.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_exact_binding.factory.dart';

class Clock {
  const Clock();
}

class Dashboard {
  @inject
  const Dashboard(this.clock);

  final Clock? clock;
}

typedef ReportBuilder = Report Function(String title);

class Report {
  const Report(this.title, this.clock);

  final String title;
  final Clock? clock;
}

class Page {
  @assistedInject
  const Page(this.clock, this.reportBuilder, @assisted this.id);

  final Clock? clock;
  final ReportBuilder reportBuilder;
  final int id;
}

@module
class AppModule {
  @provides
  Clock? provideClock() => null;

  @provides
  String provideLabel(Clock? clock) => '$clock';
}

@Component([AppModule])
abstract class AppComponent {
  Dashboard get dashboard;

  String get label;

  PageFactory get pageFactory;
}
