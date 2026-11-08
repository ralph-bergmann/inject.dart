// Golden fixture: `Foo?` entry points that only a `Foo` binding satisfies.
//
// The getters read that binding wherever it comes from: a module, a discovered
// @inject class, a child module or the parent graph. A `Foo?` getter must not
// discover an @inject class that a module or parent already binds.

import 'package:inject_annotation/inject_annotation.dart';

part 'nullable_entry_point_widened.factory.dart';

class Log {
  const Log();
}

class Clock {
  @inject
  const Clock();
}

class Timer {
  @inject
  const Timer();
}

class Db {
  const Db();
}

class Token {
  const Token();
}

@module
class SessionModule {
  @provides
  Token provideToken() => const Token();
}

@Subcomponent([SessionModule])
abstract class SessionSubcomponent {
  Token? get token;

  Clock? get clock;
}

@Module(subcomponents: [SessionSubcomponent])
class AppModule {
  @provides
  Log provideLog() => const Log();

  @provides
  Clock provideClock() => const Clock();

  @asynchronous
  @provides
  Future<Db> provideDb() async => const Db();
}

@Component([AppModule])
abstract class AppComponent {
  Log? get log;

  Log get requiredLog;

  Clock? get clock;

  Timer? get timer;

  Future<Db?> get db;

  Provider<Log?> get logProvider;

  SessionSubcomponentFactory get sessionFactory;
}
