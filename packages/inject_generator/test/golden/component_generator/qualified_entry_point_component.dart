import 'package:inject_annotation/inject_annotation.dart';

import 'qualified_entry_point_component.inject.dart' as g;

const brandName = Qualifier(#brandName);

class CoffeeModule {
  @module
  const CoffeeModule();

  @provides
  String provideName() => 'default';

  @provides
  @brandName
  String provideBrand() => 'premium';
}

@Component([CoffeeModule])
abstract class MyComponent {
  static const g.MyComponent$Component Function() create = g.MyComponent$Component.create;

  @inject
  String get name;

  @inject
  @brandName
  String get brand;
}
