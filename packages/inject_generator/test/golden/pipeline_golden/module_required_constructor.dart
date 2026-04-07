import 'package:inject_annotation/inject_annotation.dart';

import 'module_required_constructor.inject.dart' as g;

// Canonical fixture: a module with a required positional constructor.
// The generated factory must emit `required DbModule dbModule` without
// a `?? DbModule()` fallback, because `DbModule()` is not callable.

void main() {
  final comp = MainComponent.create(dbModule: DbModule('path/to/db'));
  print(comp.foo);
}

@Component([DbModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  Foo get foo;
}

@module
class DbModule {
  DbModule(this.dbPath);

  final String dbPath;

  @provides
  Foo provideDatabase() => Foo();
}

@inject
class Foo {}
