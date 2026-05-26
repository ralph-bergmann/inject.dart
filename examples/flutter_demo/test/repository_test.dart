import 'package:flutter_demo/src/data/repositories/counter_repository.dart';
import 'package:flutter_demo/src/data/services/database.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:test/test.dart';

import 'data/services/fake_database.dart';
import 'repository_test.inject.dart' as g;

void main() {
  group('CounterRepository', () {
    late CounterRepository repository;

    setUp(() {
      // [TestRepositoryComponent] uses [DatabaseModule, TestDatabaseModule].
      // [TestDatabaseModule] appears AFTER [DatabaseModule] in the list —
      // the later module wins, so its [Database] binding (backed by
      // [FakeDatabase]) overrides [DatabaseModule.provideDatabase].
      // This is the module-override semantics: list order is meaningful.
      final component = TestRepositoryComponent.create();
      repository = component.counterRepository;
    });

    test('initial count is zero', () async {
      final counter = await repository.counter;
      expect(counter.value, 0);
    });

    test('increment increases count by one', () async {
      await repository.increment();
      final counter = await repository.counter;
      expect(counter.value, 1);
    });

    test('multiple increments accumulate', () async {
      await repository.increment();
      await repository.increment();
      await repository.increment();
      final counter = await repository.counter;
      expect(counter.value, 3);
    });
  });
}

/// Test component demonstrating module override.
///
/// [DatabaseModule] is listed first (real config + real [Database] binding).
/// [TestDatabaseModule] is listed second — its [Database] binding overrides
/// the one from [DatabaseModule] because later modules win.
///
/// This means [CounterRepository] receives a [FakeDatabase] in tests, even
/// though [DatabaseModule] would normally provide the real [Database].
@Component([DatabaseModule, TestDatabaseModule])
abstract class TestRepositoryComponent {
  static const create = g.TestRepositoryComponent$Component.create;

  @inject
  CounterRepository get counterRepository;
}

/// Overrides [DatabaseModule.provideDatabase] with an in-memory fake.
///
/// The binding key is ([Database], null) — same as in [DatabaseModule].
/// Because this module appears later in [@Component(...)], it wins.
@module
class TestDatabaseModule {
  @provides
  @singleton
  Database provideDatabase(
    @databasePath String path,
    @databaseName String name,
  ) => FakeDatabase();
}
