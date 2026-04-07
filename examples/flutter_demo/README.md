# flutter_demo — inject.dart Reference Example

A layered counter app that follows Flutter's recommended architecture and
demonstrates **every** inject.dart + inject_flutter concept in one place.

If you are evaluating inject.dart, start here.
If you want the quick one-page summary, see the
[`example` package](../example/README.md).

---

## Architecture overview

The app follows the Flutter "apply architecture best practices" layers.
inject.dart replaces the `get_it` / `provider`-as-locator container that
the skill describes in Step 7 (see [Step 7 deviation](#step-7-deviation)).

| Layer            | Type in this app          | inject.dart role                               |
|------------------|---------------------------|------------------------------------------------|
| **Domain Model** | `Counter`                 | plain immutable class, no DI annotation needed |
| **Service**      | `Database`                | third-party type — provided via `@module`      |
| **Repository**   | `CounterRepository`       | `@inject @singleton`                           |
| **Use Case**     | `IncrementCounterUseCase` | `@inject`, not singleton                       |
| **ViewModel**    | `CounterViewModel`        | `@inject`, extends `ChangeNotifier`            |
| **View**         | `HomePage`, `MyApp`       | `@assistedInject` widgets                      |

Every component is obtained through inject.dart (constructor injection,
component getters, or synthesized factories). Nothing is directly
instantiated in a consumer, and there is no service locator call anywhere
in the app code.

---

## Step 7 deviation

Flutter's recommended architecture delegates dependency wiring (Step 7) to a
runtime service locator such as `get_it`, or to a `provider` tree.
inject.dart takes a different approach: **compile-time constructor injection**.

| Aspect                            | `get_it` / `injectable`     | inject.dart                          |
|-----------------------------------|-----------------------------|--------------------------------------|
| When bindings are resolved        | runtime                     | build time                           |
| Missing binding                   | crash at first `.get()`     | build error                          |
| Cyclic dependency                 | runtime error               | build error                          |
| Qualifier mismatch                | runtime                     | build error                          |
| Service locator calls in app code | yes (`GetIt.I<Foo>()`)      | none                                 |
| Registration boilerplate          | hand-written or generated   | none — annotate & run `build_runner` |
| Generated artefact                | registrations into `get_it` | full component implementation        |

`get_it` is a runtime service locator: bindings are registered in an
imperative setup block and resolved dynamically. `injectable` generates those
registrations, but the locator itself and its runtime-failure modes remain.

inject.dart generates the **entire** component implementation — all provider
classes, singleton caches, factory methods, and provision-listener wiring —
from your annotations. The generated `.inject.dart` is plain, readable Dart
that you can inspect and diff like source code.

---

## inject.dart concepts — where to find each one

| Concept                                                       | File                                                                                                          |
|---------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| `@Component` root                                             | `lib/main.dart` → `MainComponent`                                                                             |
| `@module` + `@provides @singleton`                            | `lib/src/data/services/database.dart` → `DatabaseModule`                                                      |
| Two-line `Qualifier` form                                     | `lib/src/data/services/database.dart` → `databasePath`, `databaseName`                                        |
| `@inject @singleton` Repository                               | `lib/src/data/repositories/counter_repository.dart`                                                           |
| `@inject` Use Case (Logic layer)                              | `lib/src/logic/increment_counter_use_case.dart`                                                               |
| `@inject` ViewModel + `ChangeNotifier`                        | `lib/src/features/home/counter_view_model.dart`                                                               |
| `ViewModelFactory<T>`                                         | `lib/src/features/home/home_page.dart`                                                                        |
| `@assistedInject` / `@assisted`                               | `lib/src/features/home/home_page.dart`, `lib/src/features/app/my_app.dart`                                    |
| `@asynchronous` (binding type is T, chain-wide)               | `lib/src/app_module.dart` → `provideAppInfo`, `provideWelcomeMessage`; `lib/main.dart` → `welcomeMessage`     |
| Raw `Future<T>` binding (no `@asynchronous`, consumer awaits) | `lib/src/app_module.dart` → `provideInitialCount`; `lib/src/features/home/counter_view_model.dart` → `init()` |
| `@provisionListener`                                          | `lib/src/app_module.dart` → `CreationLogListener`                                                             |
| `Provider<T>` entry point                                     | `lib/main.dart` → `counterRepositoryProvider`                                                                 |
| Module-override (test component)                              | `test/repository_test.dart` → `TestRepositoryComponent`                                                       |
| Test component with fake                                      | `test/view_model_test.dart` → `TestViewModelComponent`                                                        |

---

## Qualifier — two same-type String bindings

Two `String` config values are injected into `Database`. Type alone cannot
distinguish them; the qualifier is the second axis of binding identity:

```dart
// Declare once as a const — the two-line form keeps the symbol in one place.
const databasePath = Qualifier(#databasePath);
const databaseName = Qualifier(#databaseName);

@module
class DatabaseModule {
  @provides
  @databasePath
  String provideDatabasePath() => '/data/counter.db';

  @provides
  @databaseName
  String provideDatabaseName() => 'counter_db';

  @provides
  @singleton
  Database provideDatabase(
    @databasePath String path,   // ← routes to provideDatabasePath
    @databaseName String name,   // ← routes to provideDatabaseName
  ) => Database(path: path, name: name);
}
```

Both `@databasePath String` and `@databaseName String` have the same Dart
type. inject.dart routes them correctly because binding identity is
`(type, qualifier)`, not `type` alone.

---

## Async — two patterns compared

inject.dart distinguishes two ways to expose a `Future<T>` from a module.

### With `@asynchronous` — binding type is `T`, not `Future<T>`

```dart
// AppInfo is provided with @asynchronous:
@provides
@singleton
@asynchronous
Future<AppInfo> provideAppInfo() async { ... }

// provideWelcomeMessage is also @asynchronous AND depends on AppInfo.
// Because @asynchronous unwraps AppInfo, the parameter is AppInfo —
// not Future<AppInfo>. The generator inserted the await behind the scenes.
@provides
@singleton
@asynchronous
Future<String> provideWelcomeMessage(AppInfo appInfo) =>
    Future.value('${appInfo.name} — tap + to start counting!');
```

- The **binding type** of each `@asynchronous` provider is the awaited
  value (`AppInfo`, `String`) — not the `Future<T>`.
- Intermediate providers inject the already-resolved value directly.
- The component **entry point** is `Future<String>` because async-ness
  propagates to the boundary:

```dart
// In main():
final welcome = await component.welcomeMessage; // Future<String>
```

The `await` at the entry point is **not** a contradiction — `@asynchronous`
means "the binding type is T, so intermediate providers see T". At the
component boundary you cross back into async-world and must `await`.

### Without `@asynchronous` — binding type is `Future<T>`

```dart
@provides
@singleton
Future<int> provideInitialCount() => Future.value(0);
```

- The **binding type** is `Future<int>`.
- `CounterViewModel` injects `Future<int>` directly and awaits it in
  `init()` — the consumer resolves the Future explicitly.
- No async-ness from this provider propagates to `myAppFactory` because
  the provider chain for `provideInitialCount` is purely synchronous to
  *provision* (it just returns a pre-resolved `Future<int>`).

The difference is visible in the generated `.inject.dart`:

- `@asynchronous` providers cache `Future<T>?` and their dependents
  receive the awaited `T` value.
- Raw-`Future<T>` providers (no `@asynchronous`) return the `Future<T>`
  object directly; the consumer holds and awaits it.

**Why can `Future<int>` live in the ViewModel chain while `@asynchronous`
cannot?** `ViewModelFactory` requires synchronous provider resolution.
`provideInitialCount()` has no transitive `@asynchronous` deps, so no
async-taint propagates to `CounterViewModel`. Any `@asynchronous` binding
in the ViewModel chain would fail the generator's validation — that is why
`AppInfo` and `String` (welcome message) live in a separate branch
accessible via `component.welcomeMessage`.

---

## Provider&lt;T&gt; — lazy / on-demand access

`MainComponent` exposes `Provider<CounterRepository>` as a component entry
point:

```dart
@inject
Provider<CounterRepository> get counterRepositoryProvider;
```

`Provider<T>.get()` defers creation to call time.
Use `Provider<T>` when:

- you want lazy initialisation,
- you need to pass the provider reference to non-DI code,
- or you need multiple independent instances.

Note: `ViewModelFactory<T>` (from `inject_flutter`) is itself built on
`Provider<T>` — a concrete example of the pattern in this very repo.

---

## @provisionListener — lifecycle hook

`CreationLogListener` is registered as a `@provisionListener`. The generator
calls `onProvision` after each `ChangeNotifier` the component provisions —
here, every `CounterViewModel` instance:

```dart
@provides
@singleton
@provisionListener
CreationLogListener provideCreationLogListener() => CreationLogListener();
```

Real-world uses: centralised logging, tracking closeable resources,
lifecycle hooks for objects no framework manages automatically.

---

## Module override — how test components swap fakes

Module order in `@Component([...])` is meaningful: a later module overrides
an earlier module's binding for the same `(type, qualifier)` pair.

`test/repository_test.dart` demonstrates this:

```dart
// DatabaseModule provides the real Database.
// TestDatabaseModule appears AFTER it — its Database binding wins.
@Component([DatabaseModule, TestDatabaseModule])
abstract class TestRepositoryComponent { ... }

@module
class TestDatabaseModule {
  @provides
  @singleton
  Database provideDatabase(
    @databasePath String path,
    @databaseName String name,
  ) => FakeDatabase();  // overrides DatabaseModule.provideDatabase
}
```

This is the canonical inject.dart way to swap production bindings for fakes
in tests — no mocking framework, no global state, no `setUp`/`tearDown`
wiring beyond creating the component.

---

## Dependency graph

`build.yaml` ships with `debug_graph: true` enabled (see the file for
details). The graph below is captured verbatim from `build_runner` output.

- `(@singleton)` — one shared instance for the component lifetime
- `(@async)` — the binding is async-propagated (`@asynchronous`)
- Repeated subtrees are shown in full; nodes with ≥2 dependents appear
  multiple times — the generator shares the singleton provider across all of
  them

```
[inject_generator] Dependency graph for MainComponent:
    MainComponent
    ├── CounterRepository (@singleton)
    │   └── Database (@singleton)
    │       ├── String (@databaseName)
    │       └── String (@databasePath)
    ├── CreationLogListener (@singleton)
    ├── MyAppFactory
    │   └── HomePageFactory
    │       └── ViewModelFactory<CounterViewModel>
    │           └── CounterViewModel
    │               ├── Future<int> (@singleton)
    │               └── IncrementCounterUseCase
    │                   └── CounterRepository (@singleton)
    │                       └── Database (@singleton)
    │                           ├── String (@databaseName)
    │                           └── String (@databasePath)
    └── String (@welcome, @singleton, @async)
        └── AppInfo (@singleton, @async)
```

To disable the graph output in your own project, set `debug_graph: false`
under `inject_generator|inject_builder` in your `build.yaml`, or omit the
option entirely (it defaults to `false`).

---

## Run

```shell
dart pub get
dart run build_runner build
flutter run
```

The `build_runner` step regenerates `lib/main.inject.dart`,
`lib/src/features/app/my_app.factory.dart`, and
`lib/src/features/home/home_page.factory.dart`.

## Test

```shell
flutter test
```

Runs `test/repository_test.dart` and `test/view_model_test.dart` against
the generated test components.
