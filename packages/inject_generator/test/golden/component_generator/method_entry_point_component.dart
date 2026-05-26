import 'package:inject_annotation/inject_annotation.dart';

import 'method_entry_point_component.inject.dart' as g;

@module
class MyModule {
  @provides
  String provideName() => 'test';
}

@Component([MyModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  String getName();
}
