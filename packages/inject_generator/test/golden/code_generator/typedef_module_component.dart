import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_module_component.inject.dart' as g;

typedef OnEvent = void Function(String event);
typedef UserData = (String name, int age);

class EventLogger {
  @inject
  EventLogger(this.onEvent, this.userData);

  final OnEvent onEvent;
  final UserData userData;
}

@module
class AppModule {
  @provides
  OnEvent provideOnEvent() => print;

  @provides
  UserData provideUserData() => ('Alice', 30);
}

@Component([AppModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  EventLogger get eventLogger;
}
