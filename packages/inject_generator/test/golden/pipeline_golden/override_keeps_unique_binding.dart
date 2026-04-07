import 'package:inject_annotation/inject_annotation.dart';

import 'override_keeps_unique_binding.inject.dart' as g;

// Override is scoped to matching keys only: TestModule overrides `String message()`,
// but AppModule's unique `Counter counter()` survives (TestModule does not redefine it).
// Proves `removeWhere` in `_buildBindings()` only drops the matching key —
// a regression that broadens the predicate would silently lose unrelated bindings.

void main() {
  final comp = AppComponent.create();
  print('${comp.message}:${comp.counter.value}');
}

class Counter {
  Counter(this.value);
  final int value;
}

@Component([AppModule, TestModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  String get message;

  @inject
  Counter get counter;
}

@module
class AppModule {
  @provides
  String message() => 'app';

  @provides
  Counter counter() => Counter(42);
}

@module
class TestModule {
  @provides
  String message() => 'test';
}
