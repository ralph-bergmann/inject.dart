---
name: inject_annotation-create-module
description: Creates an inject.dart @module that provides types you cannot annotate directly — third-party classes, interfaces bound to implementations, configured values, async resources — via @provides methods, including @singleton, @asynchronous (Future<T> resolved to T), and Qualifier for multiple bindings of one type. Use when the user says "create a module", "provide X", "bind interface to implementation", "configure a dependency", needs an async/qualified binding, or hits a missing-binding error for a type without an @inject constructor.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Create a module to provide a type

A `@module` is a collection of `@provides` methods that tell inject.dart **how**
to construct types it cannot annotate directly: third-party classes
(`Dio`, `SharedPreferences`), interfaces bound to a concrete implementation,
configured values, or asynchronously created resources.

If the type is a class you own, prefer an `@inject` constructor
(`inject_annotation-add-injectable`) — it needs no module.

## Task progress

- [ ] 1. Write the `@module` class with `@provides` methods
- [ ] 2. Register the module on the component
- [ ] 3. Apply `@singleton` where one instance should be shared
- [ ] 4. Use `@asynchronous` for `Future`-returning providers
- [ ] 5. Use a `Qualifier` to distinguish same-type bindings
- [ ] 6. Regenerate and verify

## Steps

### 1. Write the module

```dart
@module
class NetworkModule {
  @provides
  @singleton
  Dio provideDio() => Dio(BaseOptions(baseUrl: 'https://api.example.com'));

  // Parameters are injected from the graph automatically.
  @provides
  ApiClient provideApiClient(Dio dio) => ApiClient(dio);
}
```

- Each provider method is annotated with `@provides`; its **return type** is the
  binding key.
- Method **parameters are injected** from the graph — depend on other bindings
  freely.
- Bind an interface to an implementation by declaring the interface as the
  return type: `@provides AuthRepo provideAuthRepo(HttpAuthRepo impl) => impl;`.

### 2. Register the module on the component

Modules only take effect once listed on a component. **Order matters**: later
modules override earlier ones for the same binding key (type + qualifier) —
this is the standard test-mock-injection mechanism.

```dart
@Component([NetworkModule, DatabaseModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  ApiClient get apiClient;
}
```

### 3. `@singleton` — share one instance

```dart
@provides
@singleton
Database provideDatabase() => SqfliteDatabase();
```

Without `@singleton`, the provider runs on every request. Async singletons
cache the `Future<T>` (not the resolved `T`) for concurrency safety.

### 4. `@asynchronous` — providers that return a `Future`

Mark a `Future`-returning provider `@asynchronous` so **dependents receive the
resolved `T`, not `Future<T>`**:

```dart
@module
abstract class StorageModule {
  @provides
  @asynchronous
  Future<SharedPreferences> providePrefs() => SharedPreferences.getInstance();
}

class Settings {
  @inject
  Settings(this._prefs);       // receives SharedPreferences, not a Future
  final SharedPreferences _prefs;
}
```

- `@asynchronous` is **only** valid on `@provides` methods (constructors can't
  be async).
- `create()` stays **synchronous**. Async resolution surfaces at the **entry
  point**: a component getter whose chain is async must be declared `Future<T>`
  (or `Provider<T>`) and you `await` that getter. A plain-`T` getter over an
  async chain is a build error.
- To inject the `Future` itself (no unwrapping), **omit** `@asynchronous` — the
  binding type stays `Future<T>` and the consumer awaits it explicitly.

### 5. `Qualifier` — multiple bindings of the same type

Define `const` qualifier constants and apply them to disambiguate:

```dart
const baseUrl = Qualifier(#baseUrl);
const timeout = Qualifier(#timeout);

@module
class ConfigModule {
  @provides
  @baseUrl
  String provideBaseUrl() => 'https://api.example.com';

  @provides
  @timeout
  Duration provideTimeout() => const Duration(seconds: 30);
}

class ApiClient {
  @inject
  ApiClient(@baseUrl this._url, @timeout this._timeout);
  final String _url;
  final Duration _timeout;
}
```

- The binding key is **type + qualifier**.
- At most **one** `Qualifier` per provider.
- Use `const` variable notation (`const baseUrl = Qualifier(#baseUrl);`), not an
  inline `@Qualifier(#baseUrl)` constructor call.

### 6. Regenerate and verify

```bash
dart run build_runner build --delete-conflicting-outputs
dart analyze
```

## Common mistakes

- **Module not registered** on any `@Component([...])` → its providers are
  invisible; missing-binding error.
- **`@asynchronous` missing** on a `Future` provider → dependents receive
  `Future<T>` instead of `T`.
- **Two unqualified providers for the same type** → ambiguous binding; add a
  `Qualifier` (or rely on module override order intentionally).
- **Inline `@Qualifier(#x)`** in fixtures/providers → use a `const` qualifier
  constant instead.
- **Stateful provider without `@singleton`** → a new instance per request,
  losing shared state.
