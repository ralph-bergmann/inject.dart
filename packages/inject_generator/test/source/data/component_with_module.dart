import 'package:inject_annotation/inject_annotation.dart';

import 'component_with_module.inject.dart' as g;

@Component(modules: [BarModule])
abstract class ComponentWithModule {
  static const create = g.ComponentWithModule$Component.create;

  Bar get bar;
}

@module
class BarModule {
  @provides
  @singleton
  Bar provideBar() => Bar();
}

class Bar {
  String get foo => 'foo';
}
