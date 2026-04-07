---
name: inject_annotation-add-injectable
description: Adds a new injectable class (service, repository, use case, view model) to an existing inject.dart graph by annotating it with @inject, declaring its dependencies as constructor parameters, optionally marking it @singleton, and exposing it from a component. Use when the user says "inject this class", "add a service/repository", "make X injectable", "share one instance with @singleton", or hits a missing-binding error for a class they own.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Add an injectable class

Use this when a class you **own** should be created and wired by inject.dart.
Annotate it with `@inject`; the generator adds it to the graph and supplies its
constructor dependencies.

If the type is a third-party class, an interface, or needs construction logic,
use `inject_annotation-create-module` instead. If the project has no component yet,
start with `inject_annotation-setup-di`.

## Task progress

- [ ] 1. Add `@inject` (on the class or a constructor)
- [ ] 2. Declare dependencies as constructor parameters
- [ ] 3. Decide on `@singleton`
- [ ] 4. (Optional) Expose it from a component
- [ ] 5. Regenerate and verify

## Steps

### 1. Add `@inject`

The idiomatic placement is **on the class**. The generator uses the class's
constructor and injects its parameters:

```dart
@inject
@singleton
class CounterRepository {
  const CounterRepository({required this.database});

  final Database database;
}
```

`@inject` placement rules (all valid):

- **On the class** — with one constructor it uses that constructor whatever its
  name; with several constructors it uses the **unnamed** one (and errors if
  there is no unnamed constructor — annotate the intended one instead).
- **On a specific constructor** — including a **named or factory** constructor:
  ```dart
  class Logger {
    @inject
    factory Logger.console() = ConsoleLogger;
  }
  ```
- **On multiple constructors** — allowed, but each must carry a **distinct
  `@Qualifier`** (the qualifier symbol must be a valid Dart identifier).

Prefer `const` constructors when all fields are `final` — it lets the generator
emit `const`/lambda providers. Both positional and named (`{required this.x}`)
parameters work.

### 2. Declare dependencies as constructor parameters

Every parameter is a dependency resolved from the graph. Each parameter type
must itself have a binding — an `@inject` class/constructor (this skill) or a
`@provides` method (`inject_annotation-create-module`). A type with no binding is a
**build error**, which is exactly inject.dart's "if it builds, it runs"
guarantee.

To defer creation or get multiple instances of a dependency, declare the
parameter as `Provider<T>` (see `inject_annotation-inject-provider`).

### 3. Decide on `@singleton`

Base this on whether the class holds **mutable state**, not on its
dependencies' lifecycles:

```dart
// Stateful/expensive → share one instance.
@inject
@singleton
class AuthService {
  AuthService(this._storage);
  final SecureStorage _storage;
}
```

- `@singleton` → one shared instance for the whole component.
- No `@singleton` → a fresh instance per dependent.
- A **stateless** collaborator (e.g. a use case that only calls others) is still
  a safe `@singleton` — it avoids needless allocations.

### 4. (Optional) Expose it from a component

Add a getter only if the type is an **entry point** resolved directly from the
component. Dependencies used only by other injectables need no getter — they
are reached transitively.

```dart
@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  CounterRepository get counterRepository;
}
```

### 5. Regenerate and verify

```bash
dart run build_runner build --delete-conflicting-outputs
dart analyze
```

## Common mistakes

- **No `@inject` anywhere** → "missing binding" for the class. Add it on the
  class or a constructor.
- **Class-level `@inject` with multiple constructors and no unnamed one** →
  build error; annotate the intended constructor directly.
- **Multiple `@inject` constructors without distinct `@Qualifier`s** → build
  error.
- **Expecting a shared instance without `@singleton`** → each dependent gets its
  own instance.
- **`@singleton` on a Flutter view model** → forbidden; view models are owned
  per widget (see `inject_annotation-flutter-view-model`).
- **`@asynchronous` on an `@inject` class** → no effect (constructors can't be
  async) and emits a warning; async belongs on `@provides` methods.
