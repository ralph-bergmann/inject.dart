import 'package:flutter_demo/src/data/services/database.dart';

/// In-memory replacement for [Database] used in tests.
class FakeDatabase extends Database {
  FakeDatabase() : super(path: 'fake', name: 'test_db');

  int _fakeCount = 0;

  @override
  Future<void> updateCount(int count) async => _fakeCount = count;

  @override
  Future<int> selectCount() => Future.value(_fakeCount);
}
