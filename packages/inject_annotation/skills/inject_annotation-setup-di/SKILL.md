---
name: inject_annotation-setup-di
description: Sets up inject.dart compile-time dependency injection in a Dart or Flutter project from scratch — adds inject_annotation, inject_generator and build_runner, scaffolds the root @component, makes a first class injectable, and runs code generation. Use when a project has no DI yet, when adding inject.dart, or when the user asks to set up dependency injection, create a component, or configure build_runner for inject.dart.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Set up inject.dart dependency injection

inject.dart is a **compile-time** DI framework. The entire dependency graph is
validated during `build_runner`: missing bindings, circular dependencies and
qualifier conflicts are **build errors**, not runtime crashes. Its promise is
**"if it builds, it runs."**

It uses **constructor injection only**. Never introduce a service locator
(`get_it`, a global registry, or `provider` used as a locator) — dependencies
are declared as constructor parameters and wired by the generated component.

## When to use this skill

- A Dart or Flutter project has no DI wiring yet.
- The user says "set up dependency injection", "add inject.dart", "create a
  component", or "configure build_runner" for inject.dart.

To grow an existing graph instead, use `inject_annotation-add-injectable` (add a
class), `inject_annotation-create-module` (provide a third-party type) or
`inject_annotation-flutter-view-model` (Flutter view models).

## Task progress

- [ ] 1. Add dependencies
- [ ] 2. Make a first class injectable
- [ ] 3. Scaffold the root component
- [ ] 4. Run code generation
- [ ] 5. Use the component
- [ ] 6. Verify

## Steps

### 1. Add dependencies

`inject_annotation` is a runtime dependency; `inject_generator` and
`build_runner` are dev-only.

```bash
# Dart project
dart pub add inject_annotation
dart pub add dev:inject_generator dev:build_runner

# Flutter project
flutter pub add inject_annotation
flutter pub add dev:inject_generator dev:build_runner
```

No `build.yaml` is required — the builders `auto_apply` to any project that
depends on `inject_generator`. (A `build.yaml` is only needed for opt-in
options such as `debug_graph: true`.)

### 2. Make a first class injectable

Annotate the class with `@inject` (the idiomatic placement). Constructor
parameters are the class's dependencies; the generator resolves them from the
graph. (`@inject` may also go on a specific constructor — including named/factory
constructors; see `inject_annotation-add-injectable`.)

```dart
@inject
class Greeter {
  const Greeter();

  String greet(String name) => 'Hello, $name!';
}
```

### 3. Scaffold the root component

A component is an **abstract** class annotated with `@component`. Each thing the
app needs is exposed as an `@inject`-annotated getter. `static const create`
points at the generated implementation, imported with the `g` prefix.

```dart
// lib/main.dart
import 'package:inject_annotation/inject_annotation.dart';

import 'main.inject.dart' as g;

@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  Greeter get greeter;
}
```

Rules: the component **must be `abstract`**; entry points are abstract getters
(`@inject` on them is **optional** — abstract getters are recognized either way
— but conventional in the examples); generated files are **always** imported
with a prefix (conventionally `g`).

### 4. Run code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

This creates `main.inject.dart` next to `main.dart`. Re-run it after **every**
annotation change. Use `watch` during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### 5. Use the component

For an all-synchronous graph, `create()` is synchronous:

```dart
void main() {
  final component = AppComponent.create();
  print(component.greeter.greet('Dart'));
}
```

`create()` stays synchronous **even when the graph contains `@asynchronous`
providers**. Async resolution surfaces at the **entry point**: a getter whose
dependency chain is async must be declared `Future<T>` (or `Provider<T>`), and
you `await` that getter — not `create()`:

```dart
@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  Future<Config> get config; // async chain → Future<T> getter
}

Future<void> main() async {
  final component = AppComponent.create(); // synchronous
  final config = await component.config;    // await the entry point
}
```

Declaring such a getter as a plain `T` is a build error that tells you to change
it to `Future<T>`.

### 6. Verify

```bash
dart analyze   # expect zero issues
```

Confirm `main.inject.dart` exists and defines `AppComponent$Component`.

## Full minimal example

```dart
// lib/main.dart
import 'package:inject_annotation/inject_annotation.dart';

import 'main.inject.dart' as g;

@inject
class Greeter {
  const Greeter();

  String greet(String name) => 'Hello, $name!';
}

@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  Greeter get greeter;
}

void main() {
  final component = AppComponent.create();
  print(component.greeter.greet('Dart')); // Hello, Dart!
}
```

## Common mistakes

- **Component not `abstract`** → it cannot be a blueprint. Mark it `abstract`.
- **Exposing a type with no binding** → missing-binding build error. The
  getter's type needs an `@inject` class/constructor or a `@provides` method.
- **No `@inject` on the class or any constructor** → the class is not
  injectable; referencing it is a missing-binding error.
- **Importing the generated file without a prefix** → always
  `import 'main.inject.dart' as g;`.
- **Expecting `await AppComponent.create()`** → `create()` is synchronous;
  `await` the `Future<T>`-typed entry-point getter instead.
