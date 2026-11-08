// Error-path fixture: two unbound function typedefs whose return type comes
// from the Dart SDK.
//
// Neither may get a typedef provider, even though the module binds `int`, the
// type of DateTime's constructor parameters. Each reports the missing binding
// at its injecting parameter and no diagnostic points into the SDK.

import 'package:inject_annotation/inject_annotation.dart';

typedef DateBuilder = DateTime Function();
typedef DelayBuilder = Future<void> Function();

class Page {
  @assistedInject
  const Page(
    this.dateBuilder,
    this.delayBuilder,
    @assisted this.title,
  );

  final DateBuilder dateBuilder;
  final DelayBuilder delayBuilder;
  final String title;
}

@assistedFactory
abstract class PageFactory {
  Page create(String title);
}

@module
class AppModule {
  @provides
  int provideYear() => 2026;
}

@Component([AppModule])
abstract class TestComponent {
  PageFactory get pageFactory;
}
