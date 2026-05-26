import 'package:inject_annotation/inject_annotation.dart';

/// Minimal reproduction of the async-chain / sync-entry-point mismatch.
///
/// DbModule provides `Future<Database>` (`@asynchronous @singleton`).
/// Repository depends on `Database` (not `Future<Database>`), so the generator
/// makes `_Repository$Provider` return `Future<Repository>`.
/// AppComponent declares a *synchronous* getter `Repository get repository`,
/// but the generated `get()` call returns `Future<Repository>`.
///
/// This type mismatch is a compile error that the in-process Dart analyzer
/// check can detect.
///
/// The generator treats this as an error-path case: it emits a validator
/// diagnostic and produces no generated output.
@Component([DbModule])
abstract class AppComponent {
  @inject
  Repository get repository;
}

@module
class DbModule {
  @provides
  @asynchronous
  @singleton
  Future<Database> provideDatabase() => Future.value(Database());
}

@inject
class Repository {
  Repository(this.db);

  final Database db; // Note: NOT Future<Database>
}

class Database {}
