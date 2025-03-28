import 'package:inject_annotation/inject_annotation.dart';

import 'component_without_module.inject.dart' as g;

@component
abstract class ComponentWithoutModule {
  static const create = g.ComponentWithoutModule$Component.create;

  @inject
  Bar getBar();

  @inject
  FooBar getFooBar();
}

@inject
class Foo {
  const Foo();

  String get foo => 'foo';
}

@inject
class Bar {
  String get bar => 'bar';
}

@inject
class FooBar {
  const FooBar(this.foo, this.bar);

  final Foo foo;
  final Bar bar;

  String get fooBar => '${foo.foo}_${bar.bar}';
}
