import 'package:flutter_demo/src/data/repositories/counter_repository.dart';
import 'package:flutter_demo/src/data/services/database.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:test/test.dart';

import 'data/services/fake_database.dart';
import 'repository_test.inject.dart' as g;

void main() {
  group('CounterRepository Test', () {
    late final CounterRepository repository;

    setUp(() {
      final component = TestComponent.create();
      repository = component.counterRepository;
    });

    test('test counter repository', () async {
      var count = await repository.count;
      expect(count, 0);

      await repository.increaseCount();
      count = await repository.count;
      expect(count, 1);
    });
  });
}

@Component(modules: [TestModule])
abstract class TestComponent {
  static const create = g.TestComponent$Component.create;

  @inject
  CounterRepository get counterRepository;
}

@module
class TestModule {
  @provides
  @singleton
  Database provideDatabase() => FakeDatabase();
}
