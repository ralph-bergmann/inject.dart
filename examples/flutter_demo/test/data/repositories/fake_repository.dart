import 'package:flutter_demo/src/data/repositories/counter_repository.dart';

class FakeCounterRepository implements CounterRepository {
  int _count = 0;

  @override
  Future<int> get count => Future.value(_count);

  @override
  Future<void> increaseCount() async {
    _count += 1;
  }
}
