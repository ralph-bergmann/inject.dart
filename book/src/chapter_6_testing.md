# Testing with Dependency Injection

One of the strongest benefits of constructor injection is testability: because
every dependency is an explicit parameter, you can substitute test
implementations without modifying production code. inject.dart's module-override
mechanism makes this a zero-boilerplate operation.

The complete test code lives in [`examples/flutter_demo/test/`][flutter-demo-test].

## The pattern in one sentence

Create a `@Component` for tests that lists a fake module **after** the real
module. The later module wins, so its binding replaces the real one.

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
*after* `DatabaseModule` in the component list, it wins. `CounterRepository`
receives a `FakeDatabase` — without any change to `CounterRepository` itself.

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

### Alternative: pass a pre-configured module instance

Listing the override module in `@Component([...])` is enough when the module
has a no-arg constructor. If the fake needs **per-test configuration**, give
the module a constructor parameter — the generated `create` then *requires* an
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

This is the same module-instance mechanism used to connect components — see
[Composing Components and Multi-Package Projects](./chapter_8_multiple_components.md).

The fake extends the real `Database` and overrides its I/O methods with
in-memory ones — so the `CounterRepository` logic is tested in isolation without
any file-system access.

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
`Future<int>` (the initial count). `IncrementCounterUseCase` is wired
automatically — it is `@inject` and its `CounterRepository` dep is satisfied by
the module.

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

## Key principles

1. **Separate test component per test scope.** One component per layer avoids
   coupling repository tests to ViewModel details and vice versa.

2. **Use modules to override, not mocking frameworks.** inject.dart tests never
   use `mockito`, `mocktail`, or similar. You provide a fake implementation and
   swap it in via a later module. The generator then produces a real, compile-
   checked component for the test — no reflection, no dynamic proxies.

3. **Every dependency is explicit.** Because every parameter is injected, you
   always know exactly what a test component uses. There is no hidden global
   state to reset between tests.

4. **The generator validates the test component too.** If `TestViewModelModule`
   forgets to provide `Future<int>`, the build fails — not the test at runtime.

## Beyond unit tests

The module-override pattern applies equally to integration and widget tests.
Create a component with a module that provides a fake HTTP client, a fake
database, or any other boundary — the rest of the graph is wired identically to
production.

[flutter-demo-test]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo/test
