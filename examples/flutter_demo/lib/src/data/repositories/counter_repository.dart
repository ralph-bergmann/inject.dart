import 'package:inject_annotation/inject_annotation.dart';

import '../services/database.dart';

/// Repository to manage the counter value.
/// Uses the [Database] to persist the counter value.
@inject
@singleton
class CounterRepository {
  CounterRepository({required Database database}) : _database = database;

  final Database _database;

  Future<int> get count async => _database.selectCount();

  Future<void> increaseCount() async {
    final count = await _database.selectCount();
    await _database.updateCount(count + 1);
  }
}
