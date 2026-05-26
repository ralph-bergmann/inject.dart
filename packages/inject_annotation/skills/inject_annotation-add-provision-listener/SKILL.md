---
name: inject_annotation-add-provision-listener
description: Adds a ProvisionListener in inject.dart to observe dependency provisioning — a cross-cutting hook called after each instance is created, for logging, metrics, lifecycle tracking, or registering Closeables. Implement ProvisionListener<T> and provide it from a @module with @provisionListener + @singleton. Use when the user says "log every provisioned dependency", "hook into object creation", "track instances", "provision listener", or wants an observer over the DI graph.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Add a ProvisionListener

A `ProvisionListener` is a cross-cutting observer invoked **after** a dependency
instance is provisioned. Use it for logging, metrics, lifecycle tracking, or
collecting `Closeable`s for later disposal — without touching the observed
classes.

`ProvisionListener<T>` comes from `package:inject_annotation`.

## Task progress

- [ ] 1. Implement `ProvisionListener` (catch-all or typed)
- [ ] 2. Provide it from a module with `@provisionListener` + `@singleton`
- [ ] 3. Register the module on the component
- [ ] 4. Regenerate and verify

## Steps

### 1. Implement the listener

A **catch-all** listener fires for every provisioned instance. Use
`ProvisionListener<Object>` — a raw `ProvisionListener` makes `onProvision` take
`dynamic`, which an `Object` parameter cannot validly override:

```dart
class LoggingListener implements ProvisionListener<Object> {
  @override
  void onProvision(Object instance) => print('Provisioned: $instance');
}
```

A **type-specific** listener fires only for instances assignable to its type
argument:

```dart
class CloseableListener implements ProvisionListener<Closeable> {
  final _open = <Closeable>[];

  @override
  void onProvision(Closeable instance) => _open.add(instance);

  Future<void> closeAll() async {
    for (final c in _open) {
      await c.close();
    }
  }
}
```

### 2. Provide it from a module

Annotate the `@provides` method with `@provisionListener`. The **return type
must implement `ProvisionListener`** — use the concrete listener class (as the
examples do) or the interface; both are valid:

```dart
@module
class AppModule {
  // Concrete return type — the catch-all listened-to type is read from the
  // `ProvisionListener<Object>` that LoggingListener implements.
  @provides
  @provisionListener
  LoggingListener provideLoggingListener() => LoggingListener();

  // Interface return type also works; here it scopes to Closeable.
  @provides
  @provisionListener
  ProvisionListener<Closeable> provideCloseableListener() =>
      CloseableListener();
}
```

`@singleton` is **optional**: provision listeners are treated as singletons
automatically. Without it the generator emits an info notice; add `@singleton`
only to silence that notice. You may register multiple listeners.

### 3. Register the module on the component

```dart
@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;
  // ...
}
```

### 4. Regenerate and verify

```bash
dart run build_runner build --delete-conflicting-outputs
dart analyze
```

## Behavior notes

- `onProvision` runs **after** the instance is created, once per provision.
- A typed `ProvisionListener<T>` fires only for instances assignable to `T`;
  `ProvisionListener<Object>` (or raw / `<dynamic>`) is a catch-all.
- Exceptions thrown from `onProvision` propagate **unhandled** to the caller —
  keep listener work cheap and defensive.

## Common mistakes

- **Missing `@provisionListener`** on the provider → the return value is treated
  as an ordinary binding, not a listener, and never fires.
- **Return type that does not implement `ProvisionListener`** → build error;
  return the concrete listener class or `ProvisionListener<T>`.
- **Heavy or throwing work in `onProvision`** → it runs on the provision path
  and unhandled exceptions surface to the caller.
