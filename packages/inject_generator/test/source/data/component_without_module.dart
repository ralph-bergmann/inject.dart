import 'package:inject_annotation/inject_annotation.dart';

import 'component_without_module.inject.dart' as g;

@component
abstract class ComponentWithoutModule {
  static const create = g.ComponentWithoutModule$Component.create;

  @inject
  Bar getBar();
}

@inject
class Bar {
  String get foo => 'foo';
}
