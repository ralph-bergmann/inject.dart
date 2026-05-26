import 'package:inject_annotation/inject_annotation.dart';

import 'mixed_modules.inject.dart' as g;

// Fixture: four modules with different constructor forms.
//
// ModuleA — required positional ctor       → factory param: required ModuleA moduleA
// ModuleB — explicit default ctor           → factory param: ModuleB? moduleB (optional + fallback)
// ModuleC — implicit default ctor           → factory param: ModuleC? moduleC (optional + fallback)
// ModuleD — const default ctor              → factory param: ModuleD? moduleD (optional + fallback)
//
// Parameters must follow the @Component declaration order — preserving the
// module override semantics (later modules override earlier ones). The
// modules below are listed alphabetically by coincidence, not by contract.

void main() {
  final comp = MainComponent.create(moduleA: ModuleA('value'));
  print(comp.serviceA);
  print(comp.serviceB);
  print(comp.serviceC);
  print(comp.serviceD);
}

@Component([ModuleA, ModuleB, ModuleC, ModuleD])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  ServiceA get serviceA;

  @inject
  ServiceB get serviceB;

  @inject
  ServiceC get serviceC;

  @inject
  ServiceD get serviceD;
}

// Required positional ctor → hasDefaultConstructor = false
@module
class ModuleA {
  ModuleA(this.value);

  final String value;

  @provides
  ServiceA provideServiceA() => ServiceA(value);
}

// Explicit default ctor → hasDefaultConstructor = true
@module
class ModuleB {
  ModuleB();

  @provides
  ServiceB provideServiceB() => ServiceB();
}

// Implicit default ctor → hasDefaultConstructor = true
@module
class ModuleC {
  @provides
  ServiceC provideServiceC() => ServiceC();
}

// Const default ctor → hasDefaultConstructor = true
@module
class ModuleD {
  const ModuleD();

  @provides
  ServiceD provideServiceD() => ServiceD();
}

class ServiceA {
  ServiceA(this.value);

  final String value;
}

class ServiceB {}

class ServiceC {}

class ServiceD {}
