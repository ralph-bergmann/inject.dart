import 'package:inject_annotation/inject_annotation.dart';

import 'nullable_entry_point_component.inject.dart' as g;

class CoffeeModule {
  @module
  const CoffeeModule();

  @provides
  String provideName() => 'default';

  @provides
  String? provideNickname() => null;
}

@Component([CoffeeModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  String get name;

  @inject
  String? get nickname;
}
