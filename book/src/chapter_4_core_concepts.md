# Core Concepts

This chapter is the complete annotation reference. Every concept maps to real
code in the [`flutter_demo`][flutter-demo] example; the table below links each
annotation to the file that demonstrates it.

| Concept                | Annotation              | Demonstrated in `flutter_demo`                     |
|------------------------|-------------------------|----------------------------------------------------|
| Constructor injection  | `@inject`               | [`counter_repository.dart`][repo]                  |
| Modules & providers    | `@module`, `@provides`  | [`database.dart`][db], [`app_module.dart`][appmod] |
| Shared instance        | `@singleton`            | [`counter_repository.dart`][repo]                  |
| Named binding          | `@Qualifier`            | [`database.dart`][db]                              |
| Async provider         | `@asynchronous`         | [`app_module.dart`][appmod]                        |
| Lazy / on-demand       | `Provider<T>`           | [`main.dart`][main]                                |
| Runtime parameters     | `@assistedInject`       | [`home_page.dart`][home], [`my_app.dart`][myapp]   |
| Provision hook         | `@provisionListener`    | [`app_module.dart`][appmod]                        |
| Use case               | `@inject @singleton`    | [`increment_counter_use_case.dart`][usecase]       |

## Constructor injection — `@inject`

Annotate a class (or a specific constructor) and the generator wires it
wherever the type is needed:

```dart
import 'package:inject_annotation/inject_annotation.dart';

@inject
class CounterRepository {
  const CounterRepository({required this._database});
  final Database _database;
  // ...
}
```

All constructor parameters become dependencies. The generator resolves them
recursively — `CounterRepository` depends on `Database`, which is provided by a
module (see below). You never call `CounterRepository(database: ...)` by hand.

**Multiple constructors:** a class may have more than one `@inject` constructor
(named or factory) — but each must carry a unique `@Qualifier` so the generator
can tell the resulting bindings apart:

```dart
const prod = Qualifier(#prod);
const fake = Qualifier(#fake);

class Service {
  @inject
  @prod
  Service.forProduction(this._client);

  @inject
  @fake
  Service.forTesting(this._mock);
}
```

Each qualified constructor becomes its own `(Service, qualifier)` binding;
consumers request the one they want with the matching `@Qualifier`.

## Modules and `@provides`

For types you do not own — third-party classes, abstract interfaces, or types
that need custom construction logic — declare a `@module` with `@provides`
methods:

```dart
@module
class DatabaseModule {
  @provides
  @singleton
  Database provideDatabase(
    @databasePath String path,
    @databaseName String name,
  ) => Database(path: path, name: name);
}
```

The generator calls `provideDatabase` whenever a `Database` is needed, passing
the correct `String` values via the qualifiers (see [`@Qualifier`](#named-bindings----qualifier) below).

A `@provides` method can itself take dependencies — the generator wires them
automatically. This creates a natural chain: modules compose into components
without manual wiring.

## Shared instances — `@singleton`

Add `@singleton` to guarantee a single instance for the component's lifetime:

```dart
@inject
@singleton
class CounterRepository { ... }

// or on a @provides method:
@module
class DatabaseModule {
  @provides
  @singleton
  Database provideDatabase(...) => ...;
}
```

`identical(component.counterRepository, component.counterRepository)` is
guaranteed to be `true`.

**View models are deliberately *not* singletons.** Each widget gets a fresh
instance with isolated state that is created in `initState` and disposed in
`dispose`. If view models were singletons, all instances of a screen would
share the same state.

## Named bindings — `@Qualifier`

When two providers return the same Dart type, a qualifier makes them distinct.
The binding identity in inject.dart is `(type, qualifier)`, not `type` alone.

The idiomatic form is two lines — declare once, use as annotation:

```dart
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
    @databasePath String path,   // routes to provideDatabasePath
    @databaseName String name,   // routes to provideDatabaseName
  ) => Database(path: path, name: name);
}
```

Both `@databasePath String` and `@databaseName String` have the same Dart type.
inject.dart routes each correctly because it tracks the qualifier alongside the
type.

**Rule:** a `@Qualifier` is part of the binding key. `@prod String` and
`@test String` are *different* keys and never override each other.

## Asynchronous providers — `@asynchronous`

inject.dart distinguishes two ways to expose a `Future<T>`:

### With `@asynchronous` — binding type is `T`

```dart
const welcome = Qualifier(#welcome);

@module
class AppModule {
  @provides
  @singleton
  @asynchronous
  Future<AppInfo> provideAppInfo() async {
    await Future.delayed(Duration.zero); // real app: SharedPreferences, platform channel, ...
    return const AppInfo(name: 'Counter App', version: '1.0.0');
  }

  @welcome
  @provides
  @singleton
  @asynchronous
  Future<String> provideWelcomeMessage(AppInfo appInfo) =>
      Future.value('${appInfo.name} — tap + to start counting!');
}
```

`@asynchronous` tells the generator: *unwrap the `Future` and register the
binding as `T`, not `Future<T>`*.

Consequences:
- `provideWelcomeMessage` receives `AppInfo` — not `Future<AppInfo>`. The
  generator inserted the `await` transparently.
- Async-ness *propagates* upward. The component entry point becomes
  `Future<String>`:

```dart
// In main():
final message = await component.welcomeMessage; // Future<String>
```

The `await` at the entry point is not a contradiction — `@asynchronous` means
"the binding type is `T` so intermediate providers see `T`". At the component
boundary you cross back into async-world.

### Without `@asynchronous` — binding type is `Future<T>`

```dart
@module
class AppModule {
  @provides
  @singleton
  Future<int> provideInitialCount() => Future.value(0);
}
```

The binding type *is* `Future<int>`. The consumer holds and awaits the future:

```dart
@inject
class CounterViewModel extends ChangeNotifier {
  CounterViewModel({required Future<int> initialCount, ...})
    : _initialCount = initialCount;

  final Future<int> _initialCount;

  Future<void> init() async {
    final value = await _initialCount;
    // ...
  }
}
```

**Important for `ViewModelFactory`:** a provider marked `@asynchronous` in the
ViewModel's dependency chain makes the entire chain async. `ViewModelFactory`
requires *synchronous* provider resolution, so mixing `@asynchronous` deps into
a ViewModel chain is a build error. Raw `Future<T>` bindings (no
`@asynchronous`) are safe because the provision itself is synchronous — the
`Future` object is handed over immediately without awaiting.

### Choosing between the two

| Use `@asynchronous` when…                         | Use raw `Future<T>` when…                          |
|----------------------------------------------------|----------------------------------------------------|
| downstream consumers should see `T`, not `Future` | the consumer owns the await (e.g. in `init()`)     |
| async-ness should propagate to the entry point    | the chain must stay synchronous (a `ViewModelFactory` dependency) |

The choice is about the **binding type** — whether dependents receive `T` or
`Future<T>` — not about how quickly the future completes. A raw `Future<T>` is
the right tool whenever a synchronous consumer sits in the chain, regardless of
whether the future resolves instantly or after a real I/O round-trip.

## Lazy and on-demand access — `Provider<T>`

A `Provider<T>` as a component entry point defers creation to call time:

```dart
@Component([AppModule, DatabaseModule])
abstract class MainComponent {
  @inject
  Provider<CounterRepository> get counterRepositoryProvider;
}

// In app code:
final repo = component.counterRepositoryProvider.get();
```

Use `Provider<T>` when:
- you want lazy initialisation (don't create until first use),
- you need to pass the provider reference to non-DI code,
- or you need multiple independent instances — but only for **non-`@singleton`**
  bindings; a `@singleton` provider returns the same cached instance on every
  `.get()`.

`ViewModelFactory<T>` (from `inject_flutter`) is itself built on `Provider<T>` —
a concrete, in-repo example of the pattern.

> **Note:** `Provider<T>` works as a component entry point, as a `@provides`
> method return type, and as a constructor parameter on any `@inject` class —
> injected like any other dependency. There the generator passes the provider
> itself (not its resolved value), so the consumer controls when `.get()` runs.

## Runtime parameters — `@assistedInject`

Some constructor parameters are only known at the call site (a route argument,
a widget key). Mark them `@assisted` and inject the rest from the graph:

```dart
class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory,   // from the DI graph
  });

  final String title;
  final ViewModelFactory<CounterViewModel> viewModelFactory;
}
```

The generator synthesises a factory class:

```dart
// generated — you never write this:
abstract class HomePageFactory {
  HomePage create({Key? key, required String title});
}
```

The factory is automatically available as a binding — inject it wherever you
build `HomePage`:

```dart
class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({@assisted super.key, required this.homePageFactory});

  final HomePageFactory homePageFactory;

  Widget build(BuildContext context) =>
      MaterialApp(home: homePageFactory.create(title: 'Counter Demo'));
}
```

### Explicit `@assistedFactory`

If you need a custom factory shape — a different method name, multiple `create`
variants, or a specific class name — declare it yourself:

```dart
@assistedFactory
abstract class CustomHomePageFactory {
  HomePage create({Key? key, required String title});
}
```

The synthesised variant is the default for the common case. An explicit
`@assistedFactory` takes precedence over synthesis.

### File setup for `@assistedInject`

Files containing `@assistedInject` constructors need a `part` directive so the
factory builder can write into them:

```dart
part 'home_page.factory.dart';
```

## Observing provisions — `@provisionListener`

`ProvisionListener<T>` is a callback fired after every instance of `T` is
created by the component. Use it for centralised logging, metrics, or tracking
resources that need explicit cleanup:

```dart
class CreationLogListener implements ProvisionListener<ChangeNotifier> {
  int _count = 0;
  int get provisionCount => _count;

  @override
  void onProvision(ChangeNotifier instance) {
    _count++;
    debugPrint('inject.dart provisioned ${instance.runtimeType} (#$_count)');
  }
}

@module
class AppModule {
  @provides
  @singleton
  @provisionListener
  CreationLogListener provideCreationLogListener() => CreationLogListener();
}
```

Three annotations work together:

- `@provides` — exposes the listener as a binding.
- `@singleton` — the same instance observes every provisioned object.
- `@provisionListener` — registers it as a hook.

The generic parameter narrows scope: `ProvisionListener<ChangeNotifier>` fires
only for `ChangeNotifier` subtypes; `ProvisionListener<Object>` is a catch-all.

## Typedef dependencies

inject.dart supports **typedef-wrapped** function types and record types as
dependency types:

```dart
typedef OnEvent = void Function(String event);
typedef UserData = (String name, int age);

class EventLogger {
  @inject
  EventLogger(this.onEvent, this.userData);
  final OnEvent onEvent;
  final UserData userData;
}

@module
class AppModule {
  @provides
  OnEvent provideOnEvent() => print;

  @provides
  UserData provideUserData() => ('Alice', 30);
}
```

Source: `packages/inject_generator/test/golden/code_generator/typedef_module_component.dart`

**Raw function types and raw record types without a typedef are not supported.**
The typedef is required for the generator to identify the dependency type
unambiguously.

### Auto-synthesized typedef: `ViewModelFactory<T>`

`ViewModelFactory<T extends ChangeNotifier>` from `inject_flutter` is a typedef:

```dart
typedef ViewModelFactory<T extends ChangeNotifier> = ViewModelBuilder<T> Function({
  Key? key,
  ViewModelInitializer<T>? init,
  Widget? loading,
  ViewModelErrorBuilder? error,
  required ViewModelWidgetBuilder<T> builder,
  Widget? child,
});
```

`init` may be synchronous or `async`. An asynchronous initializer is awaited via
a `FutureBuilder`: the `loading` widget is shown while it runs and the `error`
builder if it fails (without an `error` builder the failure is reported through
`FlutterError.reportError` rather than dropped). Both are ignored for a
synchronous `init`.

The generator synthesises the `ViewModelFactory<T>` binding automatically when
it encounters an `@inject` class that extends `ChangeNotifier`. You never write
a `@provides` method for `ViewModelFactory` — the synthesis happens behind the
scenes. This is an extension of the assisted-injection mechanism: the generator
detects that `ViewModelBuilder<T>`'s constructor accepts injectable parameters
(a `Provider<T>`) and synthesises accordingly.

## Module override semantics

When two or more modules provide the same `(type, qualifier)` pair, the **later
module wins**:

```dart
@Component([ModuleA, ModuleB])   // ModuleB overrides ModuleA for shared keys
abstract class AppComponent { ... }
```

This is the same convention as Dagger 2 on Android. It makes two patterns
trivial:

**Test-mock swap:**

```dart
// Production component
@Component([DatabaseModule])
abstract class AppComponent { ... }

// Test component — TestDatabaseModule overrides DatabaseModule's Database binding
@Component([DatabaseModule, TestDatabaseModule])
abstract class TestRepositoryComponent {
  static const create = g.TestRepositoryComponent$Component.create;

  @inject
  CounterRepository get counterRepository;
}

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

**Environment swap:** use separate components sharing a base module:

```dart
@Component([BaseModule, ProdModule])
abstract class ProdComponent { ... }

@Component([BaseModule, StagingModule])
abstract class StagingComponent { ... }
```

> **Note on qualifiers and override:** `@prod String` and `@test String` are
> *different* keys. Override only fires when both the type *and* the qualifier
> are identical.

## Builder options

Configure the generator in `build.yaml` under the `inject_generator|inject_builder`
key:

```yaml
targets:
  $default:
    builders:
      inject_generator|inject_builder:
        options:
          nullable_duplicate_binding_policy: error  # default
          debug_graph: false                        # default
```

### `nullable_duplicate_binding_policy`

Controls what happens when both `Foo?` and `Foo` exist for the same type and
qualifier:

| Value    | Behaviour                                                        |
|----------|------------------------------------------------------------------|
| `error`  | Build error (default). Having both is almost always a mistake.   |
| `warn`   | Both kept, a WARNING is emitted on the second binding.           |
| `allow`  | Both kept silently — pre-policy behaviour, useful for migration. |

### `debug_graph`

Prints a formatted dependency-graph tree per component during the build.
Off by default; enable temporarily to understand a complex graph:

```yaml
options:
  debug_graph: true
```

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
  │               └── IncrementCounterUseCase (@singleton)
  │                   └── CounterRepository (@singleton)
  │                       └── Database (@singleton)
  │                           ├── String (@databaseName)
  │                           └── String (@databasePath)
  └── String (@welcome, @singleton, @async)
      └── AppInfo (@singleton, @async)
```

If sources haven't changed since the last build, `build_runner` skips all
inputs and nothing is printed. Run a clean first:

```bash
dart run build_runner clean
dart run build_runner build
```

[flutter-demo]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo
[repo]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/data/repositories/counter_repository.dart
[db]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/data/services/database.dart
[appmod]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/app_module.dart
[main]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/main.dart
[home]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/features/home/home_page.dart
[myapp]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/features/app/my_app.dart
[usecase]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/domain/use_cases/increment_counter_use_case.dart
