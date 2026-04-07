// Error-path fixture: a nullable dependency with no matching binding.
//
// `Missing?` has no binding (neither `Missing` nor `Missing?`). The
// inject-builder must emit "No binding found for type 'Missing?'
// (also tried 'Missing')" rather than a plain "No binding found" message.

import 'package:inject_annotation/inject_annotation.dart';

abstract class Missing {}

class Consumer {
  @inject
  Consumer(this.dep);

  final Missing? dep;
}

@Component()
abstract class TestComponent {
  @inject
  Consumer get consumer;
}
