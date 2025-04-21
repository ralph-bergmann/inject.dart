import 'package:inject_annotation/inject_annotation.dart';

import 'module.inject.dart' as g;

void main() {
  final mainComponent = g.MainComponent$Component.create();
  final add = mainComponent.add;
  final sum = add(1, 2);
  print(sum);
}

@Component(modules: [MainModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  Addition get add;

  Foo get foo;

  Future<Bar> get bar;
}

typedef Addition = int Function(int a, int b);

@module
class MainModule {
  @provides
  Addition provideAddition() => _add;

  @provides
  @singleton
  Foo provideFoo() => Foo();

  @provides
  @asynchronous
  Future<Bar> provideBar({required Foo foo}) async => Bar(foo: foo);
}

int _add(int a, int b) => a + b;

class Foo {}

class Bar {
  final Foo foo;

  const Bar({required this.foo});
}
