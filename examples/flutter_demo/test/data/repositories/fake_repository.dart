import 'package:flutter_demo/src/data/repositories/counter_repository.dart';
import 'package:flutter_demo/src/domain/models/counter.dart';

/// In-memory replacement for [CounterRepository] used in tests.
class FakeCounterRepository implements CounterRepository {
  int _count = 0;

  @override
  Future<Counter> get counter => Future.value(Counter(value: _count));

  @override
  Future<void> increment() async => _count++;
}
