# Testing with Dependency Injection

Constructor injection makes code easy to test. Every dependency is an explicit
parameter, so you can substitute test implementations without changing
production code. With inject.dart's module overrides, you do this without
boilerplate.

The complete test code is in [`examples/flutter_demo/test/`][flutter-demo-test].

## The pattern

Create a `@Component` for tests that lists a fake module after the real module.
The later module wins, so its binding replaces the real one.

## Repository test

`CounterRepository` depends on `Database`. In tests, substitute `FakeDatabase`:

```dart
// test/repository_test.dart

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
  });
}

/// Test component using module-override.
///
/// [DatabaseModule] is listed first (real Database binding).
/// [TestDatabaseModule] is listed second — its Database binding overrides
/// the one from [DatabaseModule] because later modules win.
@Component([DatabaseModule, TestDatabaseModule])
abstract class TestRepositoryComponent {
  static const create = g.TestRepositoryComponent$Component.create;

  @inject
  CounterRepository get counterRepository;
}

/// Overrides [DatabaseModule.provideDatabase] with an in-memory fake.
@module
class TestDatabaseModule {
  @provides
  @singleton
  Database provideDatabase(
    @databasePath String path,
    @databaseName String name,
  ) => FakeDatabase();
}
```

`TestDatabaseModule` provides a `Database` binding for the same key
`(Database, null)` as `DatabaseModule.provideDatabase`. Because it appears
after `DatabaseModule` in the component list, it wins, and `CounterRepository`
receives a `FakeDatabase` with no change to its own code.

### `FakeDatabase`

```dart
// test/data/services/fake_database.dart

class FakeDatabase extends Database {
  FakeDatabase() : super(path: 'fake', name: 'test_db');

  int _fakeCount = 0;

  @override
  Future<void> updateCount(int count) async => _fakeCount = count;

  @override
  Future<int> selectCount() => Future.value(_fakeCount);
}
```

The fake extends the real `Database` and overrides its I/O methods with
in-memory ones, so you test the `CounterRepository` logic in isolation, without
any file-system access.

### Alternative: pass a pre-configured module instance

Listing the override module in `@Component([...])` is enough when the module
has a no-arg constructor. If the fake needs per-test configuration, give the
module a constructor parameter. The generated `create` then requires an
instance, and each test builds its own:

```dart
@module
class TestDatabaseModule {
  TestDatabaseModule(this.fake);
  final Database fake;

  @provides
  @singleton
  Database provideDatabase() => fake;
}

// In the test:
final component = TestRepositoryComponent.create(
  testDatabaseModule: TestDatabaseModule(FakeDatabase()),
);
```

The same module-instance mechanism connects components, as
[Composing Components and Multi-Package Projects](./chapter_8_multiple_components.md)
shows.

## ViewModel test

The same pattern applies one layer up. Substitute `FakeCounterRepository` to
isolate `CounterViewModel`:

```dart
// test/view_model_test.dart

import 'package:flutter_demo/src/features/home/counter_view_model.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:test/test.dart';

import 'data/repositories/fake_repository.dart';
import 'view_model_test.inject.dart' as g;

void main() {
  group('CounterViewModel', () {
    late CounterViewModel viewModel;

    setUp(() async {
      final component = TestViewModelComponent.create();
      viewModel = component.counterViewModel;
      await viewModel.init();
    });

    test('initial counter value is zero', () {
      expect(viewModel.counter, const Counter(value: 0));
    });

    test('increment updates counter via use case', () async {
      await viewModel.increment();
      expect(viewModel.counter.value, 1);
    });
  });
}

@Component([TestViewModelModule])
abstract class TestViewModelComponent {
  static const create = g.TestViewModelComponent$Component.create;

  @inject
  CounterViewModel get counterViewModel;
}

@module
class TestViewModelModule {
  @provides
  @singleton
  CounterRepository provideCounterRepository() => FakeCounterRepository();

  @provides
  Future<int> provideInitialCount() => Future.value(0);
}
```

`TestViewModelModule` provides both `CounterRepository` (as a fake) and
`Future<int>` (the initial count). The generator wires
`IncrementCounterUseCase` automatically, because it is `@inject` and the module
satisfies its `CounterRepository` dependency.

## Generating test code

After writing the test component, run the generator:

```bash
dart run build_runner build
```

This emits `test/repository_test.inject.dart` and
`test/view_model_test.inject.dart`. Then run the tests:

```bash
flutter test
```

Or for a specific file:

```bash
flutter test test/repository_test.dart
```

## Guidelines

Give each test scope its own test component. One component per layer keeps
repository tests independent of ViewModel details, and the other way around.

Override with modules and skip mocking frameworks. inject.dart tests never use
`mockito`, `mocktail`, or similar. You provide a fake implementation and swap it
in through a later module. The generator then produces a real, compile-checked
component for the test, with no reflection or dynamic proxies.

Every parameter is injected, so you always know exactly what a test component
uses, and there is no hidden global state to reset between tests.

The generator validates the test component too. If `TestViewModelModule` forgets
to provide `Future<int>`, the build fails before any test runs.

## Beyond unit tests

The module-override pattern applies equally to integration and widget tests.
Create a component with a module that provides a fake HTTP client, a fake
database, or any other boundary. The rest of the graph is wired the same way as
in production.

[flutter-demo-test]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo/test
