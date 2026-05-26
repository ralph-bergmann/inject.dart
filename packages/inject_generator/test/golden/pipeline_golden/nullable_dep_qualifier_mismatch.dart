// Qualifier-aware nullable widening diagnostic.
//
// Given an unqualified `Engine?` dep and only a `@branded Engine` binding,
// the inject-builder emits a qualifier-mismatch diagnostic ("Available
// qualified bindings: #branded") via the second-pass nullable fallback
// `_findRelatedBindings(dep.key.nonNullable)`. Before this fix,
// the validator would have emitted the generic "(also tried 'Engine')"
// message even though a qualified binding existed.

import 'package:inject_annotation/inject_annotation.dart';

const branded = Qualifier(#branded);

class Engine {
  @branded
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
  @inject
  Car get car;
}
