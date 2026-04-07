import 'package:inject_annotation/inject_annotation.dart';

import 'single_module_component.inject.dart' as g;

@module
class MyModule {
  @provides
  String provideName() => 'test';
}

@Component([MyModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  String get name;
}
