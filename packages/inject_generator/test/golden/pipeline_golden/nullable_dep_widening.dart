// Golden fixture: nullable-widening for plain @inject deps.
//
// Verifies that `Foo? foo` dependencies are resolved from non-nullable `Foo`
// @inject bindings. Dart allows implicit widening (Foo? x = nonNullableFoo),
// so the generated provider calls `fooProvider.get()` without any wrapper.

import 'package:inject_annotation/inject_annotation.dart';

import 'nullable_dep_widening.inject.dart' as g;

class Engine {
  @inject
  Engine();
}

class Car {
  @inject
  Car(this.engine);

  final Engine? engine;
}

@Component()
abstract class Garage {
  static const g.Garage$Component Function() create = g.Garage$Component.create;

  @inject
  Car get car;
}
