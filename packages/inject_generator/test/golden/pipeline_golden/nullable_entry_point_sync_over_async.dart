// Golden fixture (error path): a synchronous `Db?` getter over an @asynchronous
// `Db` provider.
//
// Nullable widening reaches the async binding, so the getter must be declared
// `Future<Db?>`. The build reports the usual sync-getter error at the getter.

import 'package:inject_annotation/inject_annotation.dart';

class Db {
  const Db();
}

@module
class AppModule {
  @asynchronous
  @provides
  Future<Db> provideDb() async => const Db();
}

@Component([AppModule])
abstract class AppComponent {
  Db? get db;
}
