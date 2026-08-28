import 'dart:developer' as developer;

import 'package:inject_annotation/inject_annotation.dart';

/// Logging contract shared by every bookshelf package.
///
/// A plain interface — no third-party logging package needed for this
/// example. [bookshelf_api] and [bookshelf_auth] both inject it without
/// depending on [CoreModule] or knowing which implementation they got.
abstract class Logger {
  void log(String message);
}

/// Default [Logger] implementation — writes to the Dart developer log so
/// output shows up in `flutter run`/`flutter test` without needing
/// `dart:io`.
class ConsoleLogger implements Logger {
  const ConsoleLogger();

  @override
  void log(String message) => developer.log(message, name: 'bookshelf');
}

/// A registered user, identified by [username].
///
/// Deliberately minimal — this example only needs enough of a "user" to
/// make the login flow feel real.
class User {
  const User({required this.username});

  final String username;
}

/// The result of a successful login: [username] plus an opaque [token].
///
/// Produced by `AuthRepository.login` and carried into the session
/// subcomponent as the `SessionComponentFactory.create` value parameter —
/// it is never a binding in the root graph, only inside the session it
/// belongs to.
class Credentials {
  const Credentials({required this.username, required this.token});

  final String username;
  final String token;
}

/// A single book in a user's shelf.
class Book {
  const Book({required this.title, required this.author});

  final String title;
  final String author;
}

/// Shared kernel: the one binding every sibling package and the app itself
/// depend on.
///
/// Listed exactly once in `MainComponent`. [bookshelf_api] and
/// [bookshelf_auth] both consume [Logger] from here — they never redeclare
/// or re-list [CoreModule] themselves, which is what keeps [Logger] a
/// single, app-wide `@singleton` instead of one per package.
@module
class CoreModule {
  @provides
  @singleton
  Logger provideLogger() => const ConsoleLogger();
}
