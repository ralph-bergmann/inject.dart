import 'package:inject_annotation/inject_annotation.dart';

// import 'module_with_inject.inject.dart' as g;

@Component(modules: [BarModule])
abstract class ModuleWithInject implements BarLocator {
  // static const create = g.ModuleWithInject$Component.create;
}

abstract class BarLocator {
  @inject
  Bar get bar;
}

@module
class BarModule {
  @inject
  Bar getBar() => Bar();
}

class Bar {
  String get foo => 'foo';
}
