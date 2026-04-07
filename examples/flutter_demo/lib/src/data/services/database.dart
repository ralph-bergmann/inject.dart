import 'package:inject_annotation/inject_annotation.dart';

/// Qualifier for the file-system path of the database.
///
/// Two-line form: declare a const top-level variable, then use it as an
/// annotation. This keeps the qualifier symbol in one place and avoids
/// repeating the literal.
///
/// Both [databasePath] and [databaseName] annotate bindings with the same
/// Dart type ([String]). Type alone cannot distinguish them — the qualifier
/// is the second axis of binding identity: (type, qualifier).
const databasePath = Qualifier(#databasePath);

/// Qualifier for the logical name of the database — a distinct [String]
/// binding alongside [@databasePath].
const databaseName = Qualifier(#databaseName);

/// Provides [Database] and its two qualified [String] configuration values.
///
/// [Database] is a simulated third-party type — it cannot carry [@inject],
/// so a [@module] is required to bind it. This is the standard pattern for
/// wrapping library types you do not control.
@module
class DatabaseModule {
  /// Provides the file-system path of the database.
  ///
  /// [@databasePath] makes this a distinct binding from [@databaseName],
  /// even though both have the same Dart type ([String]).
  @provides
  @databasePath
  String provideDatabasePath() => '/data/counter.db';

  /// Provides the logical database name.
  ///
  /// [@databaseName] is a second qualifier for the same [String] type.
  /// Together, the two bindings prove that type alone cannot identify a
  /// binding — you need (type, qualifier).
  @provides
  @databaseName
  String provideDatabaseName() => 'counter_db';

  /// Opens the [Database] using both qualified config strings.
  ///
  /// The generator routes [@databasePath String] and [@databaseName String]
  /// to the correct parameters, proving that two same-type bindings
  /// differentiated by qualifier reach the right arguments.
  ///
  /// [@singleton] ensures one shared [Database] instance for the lifetime
  /// of the component.
  @provides
  @singleton
  Database provideDatabase(
    @databasePath String path,
    @databaseName String name,
  ) => Database(path: path, name: name);
}

/// Simulates a third-party database library (e.g., Drift, Hive, Isar).
///
/// In a real app you would replace this with the actual package type. Because
/// it comes from a third party, it cannot be annotated with [@inject], which
/// is exactly why [DatabaseModule] is needed.
class Database {
  Database({required this.path, required this.name});

  final String path;
  final String name;
  int _count = 0;

  Future<void> updateCount(int count) async => _count = count;

  Future<int> selectCount() => Future.value(_count);
}
