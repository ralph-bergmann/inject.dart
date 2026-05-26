import 'package:inject_annotation/inject_annotation.dart';

import 'qualified_unqualified_same_module.inject.dart' as g;

// Fixture: same module provides both an unqualified and a @branded
// binding for the same base type. This is usually a mistake, so a WARNING
// is emitted — but codegen proceeds and both providers are generated.

const branded = Qualifier(#branded);

@module
class AppModule {
  @provides
  String provideDefault() => 'default';

  @provides
  @branded
  String provideBranded() => 'branded';
}

@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  String get defaultValue;

  @inject
  @branded
  String get brandedValue;
}
