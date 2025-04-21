import 'package:inject_annotation/inject_annotation.dart';

import 'singleton_inject.inject.dart' as g;

@Component(modules: [BarModule])
abstract class ComponentWithModule {
  static const create = g.ComponentWithModule$Component.create;

  @inject
  Foo get foo;

  @inject
  Foo2 get foo2;

  @inject
  Bar get bar;
}

@inject
@singleton
class Foo {}

class Foo2 {
  @inject
  @singleton
  const Foo2();
}

@module
class BarModule {
  @provides
  @singleton
  Bar bar(Foo foo) => Bar(foo);
}

class Bar {
  final Foo foo;

  Bar(this.foo);
}
