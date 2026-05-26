---
name: inject_annotation-write-tests
description: Writes tests for inject.dart code by defining a test @component with a test @module that overrides real bindings with fakes, then resolving subjects from the component in setUp. Use when the user says "test injected code", "write tests for my DI graph", "mock a dependency in inject.dart", "test component/module", or wants to swap a real implementation for a fake in tests.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Test inject.dart code

Constructor injection makes testing direct: build a **test component** backed by
a **test module** that overrides the real bindings with fakes, then resolve the
subject from the component. No service locator to reset, no global state.

There are two equally valid styles:

1. **Plain constructor calls** — for a unit under test with few dependencies,
   just `new` it up with fakes. No component needed.
2. **Test component** — to exercise wiring or share fakes across a graph,
   declare a component whose modules provide fakes.

This skill focuses on style 2.

## Task progress

- [ ] 1. Write fakes for the dependencies to replace
- [ ] 2. Write a test `@module` that provides the fakes
- [ ] 3. Declare a test `@component` exposing the subjects
- [ ] 4. Regenerate
- [ ] 5. Create a fresh component in `setUp` and assert

## Steps

### 1. Write fakes

Prefer hand-written fakes over mocks — they keep tests readable and refactor-safe.

A fake either **implements** the type's interface or **extends** a concrete
base (the examples use both: `FakeCounterRepository implements CounterRepository`
and `FakeDatabase extends Database`).

```dart
// implements an interface
class FakeDatabase implements Database {
  final _store = <String, Object?>{};

  @override
  Future<void> save(String key, Object? value) async => _store[key] = value;

  @override
  Future<Object?> load(String key) async => _store[key];
}
```

### 2. Write a test module

```dart
@module
class TestModule {
  @provides
  @singleton
  Database provideDatabase() => FakeDatabase();
}
```

Use `@singleton` so the subject and the test observe the **same** fake instance.

### 3. Declare a test component

```dart
import 'app_test.inject.dart' as g;

@Component([TestModule])
abstract class TestComponent {
  static const create = g.TestComponent$Component.create;

  @inject
  UserRepository get userRepository;

  @inject
  Database get database; // expose the fake to arrange/assert on it
}
```

Two override strategies:

- **Dedicated test component** (above) — list only the modules you want.
- **Reuse the production component, override one module** — because module
  order matters (later wins), `@Component([NetworkModule, TestModule])` lets
  `TestModule` replace a binding from `NetworkModule`. Use this to swap one real
  dependency while keeping the rest of the real graph.

### 4. Regenerate

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5. Write the test

```dart
void main() {
  late TestComponent component;

  setUp(() => component = TestComponent.create());

  test('UserRepository saves and loads users', () async {
    final repo = component.userRepository;
    await repo.save(User(id: '1', name: 'Alice'));

    final loaded = await repo.load('1');
    expect(loaded?.name, equals('Alice'));
  });
}
```

`TestComponent.create()` is **synchronous** (even with `@asynchronous`
bindings). If the subject needs async setup, `await` the relevant `Future<T>`
entry-point getter or the view model's `init()` in an `async` `setUp` — not
`create()` itself (as `view_model_test.dart` does: sync `create()`, then
`await viewModel.init()`).

## Best practices

- Create a **fresh** component in `setUp` to isolate each test.
- Use `@singleton` in the test module for fakes whose state you assert on.
- Test each layer in isolation; reserve full-graph resolution for integration
  tests.
- Expose only what a test needs from the test component.

## Common mistakes

- **Editing the production component for tests** → declare a separate test
  component, or override a module via `@Component` order.
- **Fake not shared** → without `@singleton` the subject and the test get
  different fake instances; assertions see no effect.
- **Expecting `await TestComponent.create()`** → `create()` is synchronous;
  await the `Future<T>` entry-point getter or `viewModel.init()` instead.
