import 'package:inject_annotation/inject_annotation.dart';

import 'parameter.inject.dart' as g;

void main() {
  ParameterComponent.create();
}

@Component(modules: [Inject2Module])
abstract class ParameterComponent {
  static const create = g.ParameterComponent$Component.create;

  @inject
  Inject1 get bar;

  @inject
  Inject2 get bar2;

  @inject
  Inject3 get bar4;
}

@inject
class Inject1 {
  final Dependency1? foo;
  final Dependency1? foo2;
  final Dependency1? foo3;

  const Inject1(this.foo, {this.foo2, required this.foo3});
}

class Inject2 {
  final Dependency1? foo;
  final Dependency1? foo2;
  final Dependency1? foo3;

  const Inject2(this.foo, {this.foo2, required this.foo3});
}

@module
class Inject2Module {
  @provides
  Inject2 bar(
    Dependency1? foo, {
    Dependency1? foo2,
    required Dependency1? foo3,
  }) =>
      Inject2(foo, foo2: foo2, foo3: foo3);
}

@inject
class Inject3 {
  final Inject4Factory factory;
  final Inject5Factory factory2;

  const Inject3(this.factory, this.factory2);
}

@assistedInject
class Inject4 {
  final Dependency2 foo;
  final Dependency1? foo2;
  final Dependency1? foo3;
  final Dependency1? foo4;

  const Inject4(@assisted this.foo, this.foo2, {this.foo3, required this.foo4});
}

@assistedFactory
abstract class Inject4Factory {
  Inject4 create(Dependency2 foo);
}

@assistedInject
class Inject5 {
  final Dependency2 foo;

  const Inject5(@assisted this.foo);
}

@assistedFactory
abstract class Inject5Factory {
  Inject5 create(Dependency2 foo);
}

@inject
class Dependency1 {}

class Dependency2 {}
