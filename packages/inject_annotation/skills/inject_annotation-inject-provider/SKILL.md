---
name: inject_annotation-inject-provider
description: Injects a Provider<T> in inject.dart instead of T to defer construction to call time or to obtain multiple independent instances of a non-singleton (object pools, lazy or optional dependencies, per-operation instances). Use when the user says "lazy dependency", "create instances on demand", "Provider<T>", "object pool", or needs more than one instance of a type, or wants to avoid building a dependency until it is actually needed.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Inject `Provider<T>` for lazy or multiple instances

By default a constructor parameter of type `T` is built **eagerly** and once per
dependent. Inject `Provider<T>` instead to:

- **defer** construction until `provider.get()` is first called (lazy/optional
  dependencies), or
- obtain **multiple independent instances** of a non-singleton (object pools,
  per-operation instances).

`Provider<T>` comes from `package:inject_annotation`. The generator supplies a
concrete implementation — you never implement it.

## Task progress

- [ ] 1. Declare the parameter as `Provider<T>`
- [ ] 2. Call `.get()` where the instance is needed
- [ ] 3. Confirm a binding for `T` exists
- [ ] 4. Regenerate and verify

## Steps

### 1. Declare a `Provider<T>` — as a constructor parameter or a component getter

As a **constructor parameter** on any `@inject` class:

```dart
@inject
class ConnectionPool {
  const ConnectionPool(this._createConnection);

  final Provider<Connection> _createConnection;

  Connection lease() => _createConnection.get();
}
```

As a **component entry-point getter** (e.g. to hand the provider to non-DI code,
or for lazy access):

```dart
@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  Provider<Connection> get connectionProvider;
}
```

### 2. Call `.get()` when you need an instance

- If `Connection` is **not** a `@singleton`, each `get()` returns a **fresh**
  instance — ideal for pools and per-request objects.
- If `Connection` **is** a `@singleton`, every `get()` returns the **same**
  cached instance, but construction is still deferred until the first call.

### 3. Confirm a binding for `T` exists

inject.dart resolves `Provider<T>` to the binding for its inner type `T`. That
binding must exist (an `@inject` class/constructor or a `@provides` method) — a
missing `T` is a build error, just as for a direct `T` injection.

As a **constructor parameter**, `Provider<Future<T>>` injects a provider over a
raw `Future<T>` binding (a `@provides` returning `Future<T>` with **no**
`@asynchronous`). The inner `Future<T>` is **preserved** (not unwrapped to `T`):
`.get()` returns the `Future<T>`, which you `await`. Keep `Provider<Future<T>>`
to constructor parameters — as a component entry-point getter over a raw
`Future<T>` binding it does **not** resolve (the generator unwraps it and looks
for a bare `T`).

### 4. Regenerate and verify

```bash
dart run build_runner build --delete-conflicting-outputs
dart analyze
```

## When to use `Provider<T>` vs direct `T`

| Need | Inject |
|------|--------|
| One eager dependency | `T` |
| Build only if/when used | `Provider<T>` |
| A fresh instance per call | `Provider<T>` (non-singleton `T`) |
| Lazy access to a `Future<T>` binding | `Provider<Future<T>>` |

## Common mistakes

- **Implementing `Provider<T>` by hand** → never; the generator provides it.
- **Expecting fresh instances from a `@singleton`** → a singleton's `get()`
  always returns the same instance; drop `@singleton` for per-call instances.
- **Injecting `Provider<T>` for a type with no binding** → still a build error;
  the inner `T` must be resolvable.

> Flutter note: a `ViewModelFactory<T>` wraps a `Provider<T>` internally — use
> `inject_annotation-flutter-view-model` for `ChangeNotifier` view models rather than a
> raw `Provider`.
