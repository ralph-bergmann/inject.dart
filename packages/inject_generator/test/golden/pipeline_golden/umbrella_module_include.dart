import 'package:inject_annotation/inject_annotation.dart';

import 'umbrella_module_include.inject.dart' as g;

// I/O-matrix row: "Single-level include" — the component lists only
// UmbrellaModule; GreetingModule's provider must be pulled in transitively
// and appear in the generated graph exactly as if it had been listed
// directly on @Component.

void main() {
  final comp = AppComponent.create();
  print(comp.greeting);
}

@Component([UmbrellaModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  String get greeting;
}

@module
class GreetingModule {
  @provides
  String provideGreeting() => 'hello';
}

@Module(includes: [GreetingModule])
class UmbrellaModule {}
