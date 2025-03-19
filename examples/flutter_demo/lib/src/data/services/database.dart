import 'package:inject_annotation/inject_annotation.dart';

/// Module to provide the database instance.
/// Modules are used to provide instances of classes from 3rd party libraries
/// that can't be annotated with [inject].
@module
class DataBaseModule {
  @provides
  @singleton
  Database provideDatabase() => Database();
}

/// Simulates a 3rd party database library for demonstration purposes.
///
/// This class mimics what you might find in an actual database package
/// like Drift, Isar, or Hive, but with simplified functionality to focus
/// on dependency injection concepts. In a real app, you would replace this
/// with an actual database implementation.
///
/// Usage example:
/// ```dart
/// final db = Database();
/// await db.updateCount(5);
/// final value = await db.selectCount(); // Returns 5
/// ```
class Database {
  /// In-memory storage for the counter value.
  /// In a real database, this would be persisted to disk.
  int _count = 0;

  /// Simulates updating a record in the database.
  ///
  /// In a real database, this would write to persistent storage.
  Future<void> updateCount(int count) async {
    _count = count;
  }

  /// Simulates reading a record from the database.
  ///
  /// In a real database, this would fetch data from persistent storage.
  Future<int> selectCount() {
    return Future.value(_count);
  }
}
