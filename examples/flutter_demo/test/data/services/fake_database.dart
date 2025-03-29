import 'package:flutter_demo/src/data/services/database.dart';

class FakeDatabase implements Database {
  int _count = 0;

  @override
  Future<void> updateCount(int count) async {
    _count = count;
  }

  @override
  Future<int> selectCount() {
    return Future.value(_count);
  }
}
