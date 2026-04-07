import 'package:inject_annotation/inject_annotation.dart';

import '../../domain/models/counter.dart';
import '../services/database.dart';

/// Repository for the counter value.
///
/// Sits between [Database] (raw storage layer) and the rest of the app.
/// Consumers — ViewModels, Use Cases — always work with [Counter] domain
/// models and never touch the raw [Database] type directly.
///
/// [@singleton] ensures one shared instance: the counter state is consistent
/// across the entire app without any static variable or service locator.
@inject
@singleton
class CounterRepository {
  const CounterRepository({required this._database});

  final Database _database;

  /// Reads the current counter as a [Counter] domain model.
  Future<Counter> get counter async => Counter(value: await _database.selectCount());

  /// Increments the persisted counter by one.
  Future<void> increment() async {
    final current = await _database.selectCount();
    await _database.updateCount(current + 1);
  }
}
