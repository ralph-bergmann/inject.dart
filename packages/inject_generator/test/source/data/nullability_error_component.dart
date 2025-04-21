import 'package:inject_annotation/inject_annotation.dart';

@Component(modules: [BarModule])
abstract class ComponentNullability {
  @inject
  FooBar get fooBar;

  @inject
  Foo get foo;

  @inject
  Bar get bar;
}

@module
class BarModule {
  @provides
  FooBar fooBar(Foo foo, Bar? bar) => FooBar(foo, bar: bar);

  @provides
  Foo foo() => Foo();

  @provides
  Bar? bar() => null;
}

class FooBar {
  final Foo foo;
  final Bar? bar;

  const FooBar(this.foo, {required this.bar});
}

class Foo {}

class Bar {}
