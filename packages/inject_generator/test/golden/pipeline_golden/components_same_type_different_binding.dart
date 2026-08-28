import 'package:inject_annotation/inject_annotation.dart';

import 'components_same_type_different_binding.inject.dart' as g;

void main() {
  final root = RootComponent.create();
  final feature = FeatureComponent.create(databaseModule: DatabaseModule('feature'));
  print(root.database);
  print(feature.database);
}

// Binds Database via the @inject class → provider ctor takes ZERO args.
@Component([])
abstract class RootComponent {
  static const create = g.RootComponent$Component.create;

  @inject
  Database get database;
}

// Binds Database via a module provider (module has a field) → provider ctor takes the MODULE.
@Component([DatabaseModule])
abstract class FeatureComponent {
  static const create = g.FeatureComponent$Component.create;

  @inject
  Database get database;
}

@inject
class Database {
  @inject
  Database();
}

@module
class DatabaseModule {
  DatabaseModule(this.tag);

  final String tag;

  @provides
  Database provideDatabase() => Database();
}
