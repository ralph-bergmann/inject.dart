# AI rules for inject.dart

You are an expert in Dart and Flutter development using inject.dart for
compile-time dependency injection. Your goal is to help developers build
correct, maintainable, and testable applications by leveraging inject.dart's
annotation-driven, build-time DI system.

inject.dart's core promise is **"If it builds, it runs."** The entire
dependency graph is validated at build time — missing bindings, circular
dependencies, and qualifier conflicts are all build errors, not runtime
crashes. Every suggestion you make must serve that guarantee.

## Interaction Guidelines

* **Persona:** Assume the user is a Dart or Flutter developer who may be
  familiar with service-locator patterns (get_it, riverpod) but new to
  compile-time DI.
* **Clarification:** If a request is ambiguous, ask whether the user is
  working on a pure Dart or Flutter project, and whether the dependency in
  question is synchronous or asynchronous.
* **Never suggest service-locator patterns:** Do not suggest `get_it`,
  `provider` (as a service locator), or manual `ServiceLocator` classes.
  inject.dart is constructor injection only — dependencies are explicit,
  not looked up at runtime.
* **Code Generation:** Whenever annotations are added or changed, remind the
  user to run the build_runner command.

## Setup

### Adding Dependencies

```bash
# Dart project
dart pub add inject_annotation
dart pub add dev:inject_generator dev:build_runner

# Flutter project
flutter pub add inject_annotation
flutter pub add dev:inject_generator dev:build_runner
```

### Running Code Generation

After adding or modifying annotated classes, always run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For watch mode during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Generated Files

inject.dart generates two types of files:

| File                  | Builder        | Purpose                      |
|-----------------------|----------------|------------------------------|
| `<name>.inject.dart`  | LibraryBuilder | Component implementation     |
| `<name>.factory.dart` | PartBuilder    | Assisted injection factories |

Generated files are always imported with a prefix to distinguish generated
from hand-written code:

```dart
import 'main.inject.dart' as g;
```

## Core Concepts

### The Dependency Graph

inject.dart builds a complete dependency graph at build time. Every type that
must be provided is resolved statically. If a binding is missing, the build
fails — the app never starts in a broken state.

### Constructor Injection

inject.dart uses **constructor injection exclusively**. Dependencies are
declared as constructor parameters — never looked up via a registry.

```dart
// ✅ CORRECT — constructor injection
class OrderService {
  @inject
  const OrderService(this._repository, this._logger);

  final OrderRepository _repository;
  final Logger _logger;
}

// ❌ WRONG — service locator (not inject.dart pattern)
class OrderService {
  final _repository = GetIt.I<OrderRepository>();
}
```

## Annotation Reference

### `@component` / `@Component([Module1, Module2])`

Marks an abstract class as the **root of the dependency graph**. A component
exposes the objects that the application needs.

```dart
import 'package:inject_annotation/inject_annotation.dart';
import 'main.inject.dart' as g;

// No modules — all dependencies via @inject constructors
@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  AppService get appService;
}

// With modules — dependencies provided via @provides methods
@Component([NetworkModule, DatabaseModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  AppService get appService;
}
```

**Rules:**

- Must be `abstract`.
- Components declare **no constructors**. `@inject` and `@assistedInject`
  constructors belong on injectable classes — never on a component class. The
  generated `create` factory is the only way a component is instantiated.
- Entry points are exposed as **abstract getters** (or abstract methods).
  Annotating them with `@inject` is **optional** — an abstract getter on a
  component is recognized as an entry point either way. Annotating is the
  convention used throughout the examples; do so for clarity and consistency.
  This includes getters **inherited from an `implements` clause** — a
  component that `implements SomeInterface` gets `SomeInterface`'s abstract
  getters as entry points automatically, without re-declaring them.
- The static `create` reference points to the generated implementation.
- The generated `create` factory takes one **named parameter per module**
  (in `@Component([...])` declaration order): optional when the module has a
  public no-arg constructor (falls back to `Module()`), **`required`**
  otherwise. Passing a pre-built module instance is the supported way to feed
  runtime values or externally-constructed objects into the graph — including
  objects obtained from another component (root → feature component wiring).
- Root → feature component wiring has two shapes: pass an already-built
  object through a module constructor (above) for a handful of objects; or,
  for many/async objects, or when the two components have no parent/child
  relationship at all, define a narrow interface that the other component
  `implements` and have the module consume only that interface — the
  equivalent of Dagger's `@Component(dependencies: [...])`. See "Interface
  bridge" below.
- For an **encapsulated child graph** instead — one that reads every parent
  binding but keeps its own bindings private, scoped to its own instance —
  use `@subcomponent` / `@Module(subcomponents: ...)` below instead of a
  second independent `@Component`.
- Module list order matters: later modules override bindings from earlier ones.

### `@module`

Marks a class as a **collection of providers**. Use modules to provide
third-party types or to control how instances are created.

```dart
@module
class NetworkModule {
  @provides
  HttpClient provideHttpClient() =>
      HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
}
```

**Rules:**

- Provider methods are annotated with `@provides`.
- Method parameters are injected from the graph automatically.
- Modules are registered on the component: `@Component([NetworkModule])`.

### `@Module(includes: [...])`

Folds another module's providers into this one, transitively — lets a
library author bundle several internal modules behind one public "umbrella"
module, so a consuming app only has to list that one module.

```dart
// Inside the library — not exported.
@module
class ApiModule {
  @provides
  ApiClient provideApiClient() => ApiClient();
}

@module
class DbModule {
  @provides
  Database provideDatabase() => Database();
}

// The library's public surface.
@Module(includes: [ApiModule, DbModule])
class MyLibraryModule {}

// App code only ever lists MyLibraryModule.
@Component([MyLibraryModule])
abstract class AppComponent { /* ... */ }
```

**Rules:**

- `includes` is followed transitively (an included module can itself include
  more modules), and a module reachable through more than one include path
  is installed exactly once — the first-reached position in the include
  traversal wins, which is what determines its place in the override order
  — so diamond-shaped include graphs are safe. A module that transitively
  includes itself is a compile-time error.
- A component's (or subcomponent's) own **directly-listed** modules always
  take precedence over anything pulled in through `includes`. When a module
  both provides its own bindings and includes another module for the same
  key, the including module's own providers win.
- Included modules are still ordinary `create()` parameters: each included
  module class must stay **public**, the same as a directly-listed one, and
  one with no usable no-argument constructor becomes a **required**
  parameter on the *component's* (or subcomponent's) generated `create()`
  — there is no separate generated factory for the umbrella module itself.
- `includes` and `subcomponents` (below) are independent `@Module`
  parameters — an included module can declare its own `subcomponents:`.

### `@subcomponent` / `@Module(subcomponents: [...])`

Marks an abstract class as an **encapsulated child graph**, installed into a
parent component through a module. The child can read every binding of the
parent; the parent cannot see any of the child's own bindings unless a
module provider explicitly re-exports one.

```dart
@module
class HttpModule {
  @provides
  @singleton
  HttpClient provideClient() => HttpClient();

  @provides
  RestApiService provideApi(HttpClient client, Database db) =>
      RestApiService(client, db); // Database comes from the parent.
}

@Subcomponent([HttpModule])
abstract class HttpSubcomponent {
  RestApiService get apiService;
}

@Module(subcomponents: [HttpSubcomponent])
class NetworkModule {}

@Component([NetworkModule])
abstract class AppComponent {
  @inject
  Database get db;

  @inject
  HttpSubcomponentFactory get httpFactory; // synthesized, bound in the parent
}

// Usage:
final app = AppComponent.create();
final http = app.httpFactory.create();
print(http.apiService); // HttpClient itself stays private to the subgraph.
```

**Rules:**

- Installing a subcomponent via `subcomponents:` synthesizes a
  `<Name>Factory` class and binds it as an ordinary **parent** binding —
  inject it anywhere in the parent graph and call `create(...)` for a fresh
  child instance.
- The synthesized factory is generated into the `.factory.dart` **part
  file** of the library that declares the `@Subcomponent` — that file needs
  its own `part '<file>.factory.dart';` directive, exactly like an
  `@assistedInject` file.
- `@singleton` inside the subcomponent means once **per subcomponent
  instance**, not once per app. Parent `@singleton`s stay app-wide, shared
  by every child instance built from that parent.
- A subcomponent must **not** re-declare a binding key the parent already
  provides — that is a compile-time error, not an override.
- `@asynchronous` propagates across the parent/child boundary: a child
  entry point whose dependency chain reaches an async parent binding must
  be declared `Future<T>`. `create(...)` itself always stays synchronous,
  exactly like a component's.
- Multi-level hierarchies (a subcomponent installing its own subcomponents)
  are **not supported**.
- `@provisionListener` does **not** cross the parent/child boundary — a
  listener registered in one graph never observes provisions in the other.
- To re-export one child binding to the parent, give a parent module
  provider a dependency on the subcomponent factory and call `.create()`
  from it. The re-declare rule above applies to the re-export too: the
  child must bind the type under a different key — typically a
  `@Qualifier` — so the parent's unqualified binding does not collide.
  For the example above: add `const internal = Qualifier(#internal);`,
  annotate `HttpModule.provideApi` and the `apiService` entry point with
  `@internal`, then:

  ```dart
  @Module(subcomponents: [HttpSubcomponent])
  class NetworkModule {
    @provides
    @singleton
    RestApiService provideApi(HttpSubcomponentFactory factory) =>
        factory.create().apiService;
  }
  ```

### `@subcomponentFactory`

Replaces the synthesized `<Name>Factory` with an explicit one that also
accepts **runtime values** directly, without wrapping them in a module
constructor:

```dart
@subcomponentFactory
abstract class HttpSubcomponentFactory {
  HttpSubcomponent create(HttpModule module, String userId);
}
```

**Rules:**

- Must be `abstract` and declare exactly one abstract method returning the
  installed `@subcomponent` type; it replaces the synthesized factory for
  that subcomponent.
- A parameter whose type is one of the subcomponent's own declared modules
  behaves exactly like a synthesized factory's module parameter.
- Every other parameter is a **value parameter**: it becomes an instance
  binding in the child graph, injectable under its `(type, qualifier)` —
  honoring nullable-wrap resolution like any other binding — the
  equivalent of Dagger's `@BindsInstance`.
- A value parameter whose `(type, qualifier)` collides with a binding the
  parent already provides is a build error — it counts as re-declaring a
  parent key, same as a child module provider would.
- `create(...)` stays synchronous, exactly like the synthesized factory.

### Interface bridge (cross-component access without a shared parent)

When two components have no parent/child relationship — or a feature needs
many objects, an async one, or must not statically reference the other
component at all (e.g. a deferred-loaded Flutter feature) — bridge them
with a narrow interface instead of passing instances:

```dart
// feature side — states what it needs, names no app type:
abstract class AppDeps {
  Db get db;
}

@module
class BridgeModule {
  BridgeModule(this.deps);
  final AppDeps deps;

  @provides
  Db db() => deps.db;
}

@Component([BridgeModule])
abstract class FeatureComponent { /* entry points */ }

// app side — satisfies the feature-defined interface. `db` is inherited
// as an entry point; AppComponent does not re-declare it.
@Component([DbModule])
abstract class AppComponent implements AppDeps {}

// wiring:
final app = AppComponent.create();
final feature = FeatureComponent.create(bridgeModule: BridgeModule(app));
```

**Rules:**

- This is the inject.dart equivalent of Dagger's `@Component(dependencies:
  [...])` (and of Hilt's `@EntryPoint`-based dynamic-feature-module
  recipe) — but the dependency points the other way: the **feature**
  defines the interface, the **app** implements it, and the feature never
  names an app type.
- **Lazy:** the bridge module's provider calls the interface getter every
  time the feature graph resolves that binding — nothing is captured
  eagerly when the bridge module is constructed.
- **Scope-preserving:** `@singleton` caching happens in whichever graph
  owns the binding (the app, above) — the bridge never creates a second
  instance.
- **Async-transparent:** declare the interface getter as `Future<T>` and
  the bridge's provider `@provides @asynchronous Future<T>`; the `await`
  happens where the feature graph resolves the entry point, never where
  the bridge module is constructed.
- A deferred-loaded feature must use this pattern, not a `@subcomponent` —
  a subcomponent's factory is a type the parent module references
  directly, which (per Dart's loading-unit rules) would pull the whole
  feature into the base loading unit. The shared interface (`AppDeps`
  above) must live in a library both sides import normally — Dart forbids
  using a deferred library's types in the file that imports it.
- A fake implementation of the interface is the natural test seam for the
  feature component — no test parent component needed on this axis.

### `@inject`

Marks a class (or a specific constructor) as injectable, or a **getter** in a
component as an exposed provider. The constructor parameters are the class's
dependencies.

```dart
// On the class — the idiomatic style. inject.dart uses its constructor.
@inject
@singleton
class UserRepository {
  const UserRepository({required this.database});

  final Database database;
}

// On a component getter — expose this type from the component
@component
abstract class AppComponent {
  @inject
  UserRepository get userRepository;
}
```

**Constructor selection rules:**

- `@inject` may be placed **on the class** or **on a constructor** — including a
  **named or factory** constructor (`@inject factory Foo.create(...)` is valid).
- Class-level `@inject` with **one** constructor uses that constructor whatever
  its name. With **multiple** constructors it uses the **unnamed** one; if there
  is no unnamed constructor, that is a build error — annotate the intended
  constructor instead.
- A class may have **multiple `@inject` constructors**, but then each one must
  carry a **distinct `@Qualifier`** (the qualifier symbol must be a valid Dart
  identifier).
- A class with no `@inject` anywhere is **not** injectable — referencing it is a
  missing-binding build error (use a `@module` for types you cannot annotate).

### `@provides`

Marks a **method in a module** as a provider for the dependency graph.

```dart
@module
class AppModule {
  @provides
  Database provideDatabase() => SqfliteDatabase();

  // Parameters are injected from the graph
  @provides
  UserRepository provideUserRepository(Database database) =>
      UserRepository(database);
}
```

### `@singleton`

Ensures that **only one instance** is created and reused for all dependents.

```dart
// On a class
@inject
@singleton
class AuthService {
  AuthService(this._storage);

  final SecureStorage _storage;
}

// On a module provider
@module
class AppModule {
  @provides
  @singleton
  Database provideDatabase() => SqfliteDatabase();
}
```

**Rules:**

- Singletons are scoped to the component instance.
- For synchronous singletons, inject.dart generates `late final`.
- For asynchronous singletons, inject.dart caches the `Future<T>` — not the
  resolved `T` — for concurrency safety.

### `@asynchronous`

Marks a module provider that returns a `Future<T>`. Dependents receive the
resolved `T`, not `Future<T>`.

```dart
@module
abstract class StorageModule {
  @provides
  @asynchronous
  Future<SharedPreferences> providePreferences() =>
      SharedPreferences.getInstance();
}

// Dependent receives SharedPreferences directly, not Future<SharedPreferences>
class SettingsService {
  @inject
  SettingsService(this._prefs);

  final SharedPreferences _prefs;
}
```

**Rules:**

- `@asynchronous` is **only valid on `@provides` methods** in modules.
  Dart constructors cannot be async, so `@asynchronous` on an `@inject`
  class is meaningless. The generator must **never** read, store, or act on
  `@asynchronous` for `@inject`-annotated classes, and tests must **never**
  assert async behaviour for constructor-injected types.
- When the generator encounters `@asynchronous` on an `@inject` class, it
  must emit a **diagnostic warning** informing the user that the annotation
  has no effect on constructor-injected types and is only valid on
  `@provides` methods in `@module` classes.
- `create()` is **always synchronous** — it constructs the component. Async
  resolution surfaces at the **entry point**: a component getter whose
  dependency chain is `@asynchronous` must be declared `Future<T>` (or
  `Provider<T>`), and you `await` that getter. Declaring such a getter as a
  plain `T` is a build error ("declared synchronous but its dependency chain is
  asynchronous — change the return type to `Future<T>`").
- Do not annotate a provider with `@asynchronous` if you want to inject the
  `Future` itself — omit the annotation, and the binding type stays `Future<T>`
  (the consumer awaits it explicitly).

### `@Qualifier(#name)` / custom qualifier constants

Distinguishes **multiple bindings for the same type**.

```dart
// Define qualifier constants
const baseUrl = Qualifier(#baseUrl);
const timeout = Qualifier(#timeout);

@module
class NetworkModule {
  @provides
  @baseUrl
  String provideBaseUrl() => 'https://api.example.com';

  @provides
  @timeout
  Duration provideTimeout() => const Duration(seconds: 30);
}

// Inject qualified dependency
class ApiClient {
  @inject
  ApiClient(@baseUrl this._baseUrl, @timeout this._timeout);

  final String _baseUrl;
  final Duration _timeout;
}
```

**Rules:**

- A `Qualifier` is a `const` instance of the `Qualifier` class.
- The binding key is the combination of **type + qualifier**.
- At most one `@Qualifier` per provider is allowed.

### `@provisionListener` + `ProvisionListener<T>`

Registers an observer that is called **after** a dependency instance is
provisioned — useful for logging, lifecycle tracking, or registering
`Closeable`s. Implement `ProvisionListener<T>` and provide it from a module
with `@provisionListener`.

```dart
// Catch-all listener: ProvisionListener<Object> fires for every provision.
// (Use <Object>, not a raw `ProvisionListener` — the raw form makes
// onProvision take `dynamic`, which an `Object` parameter cannot override.)
class LoggingListener implements ProvisionListener<Object> {
  @override
  void onProvision(Object instance) => print('Provisioned: $instance');
}

// Type-specific listener: fires only for Closeable instances.
class CloseableListener implements ProvisionListener<Closeable> {
  @override
  void onProvision(Closeable instance) => _track(instance);
}

@module
class AppModule {
  @provides
  @singleton
  @provisionListener
  ProvisionListener provideLoggingListener() => LoggingListener();

  @provides
  @singleton
  @provisionListener
  ProvisionListener<Closeable> provideCloseableListener() =>
      CloseableListener();
}
```

**Rules:**

- The provider method must be annotated with `@provisionListener`, and its
  **return type must implement `ProvisionListener`** — either the concrete
  listener class (e.g. `CreationLogListener`) or the interface
  (`ProvisionListener<T>`). A return type that does not implement
  `ProvisionListener` is a build error.
- `@singleton` is **optional**: provision listeners are treated as singletons
  automatically. Without `@singleton` the generator emits an info notice;
  adding it just silences that notice.
- The listened-to type is read from the `ProvisionListener<T>` the return type
  implements. `ProvisionListener<T>` fires only for instances assignable to
  `T`; `ProvisionListener<Object>` (or raw / `<dynamic>`) is a catch-all that
  fires for every provision. For a catch-all, prefer `ProvisionListener<Object>`
  — it lets `onProvision(Object instance)` type-check, whereas a raw
  `ProvisionListener` forces a `dynamic` parameter.
- Exceptions thrown from `onProvision` propagate unhandled to the caller.

## Lazy Injection with `Provider<T>`

Inject `Provider<T>` instead of `T` to **defer construction to call time** or
to obtain **multiple independent instances** of a non-singleton. The generator
supplies a concrete `Provider<T>`; you never implement it.

```dart
class ConnectionPool {
  // Each `_create.get()` returns a fresh Connection (when not a @singleton).
  @inject
  ConnectionPool(this._create);

  final Provider<Connection> _create;

  Connection lease() => _create.get();
}
```

`Provider<T>` works in **two places** — as a constructor parameter (above) and
as a **component entry-point getter**:

```dart
@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  Provider<Connection> get connectionProvider; // lazy entry point
}
```

**Rules:**

- A `Provider<T>` is resolved to the binding for its inner type `T`; that
  binding must exist (a missing `T` is a build error, same as a direct `T`).
- Calling `.get()` invokes the provider each time — a `@singleton` returns the
  same cached instance; a non-singleton returns a new instance per call.
- As a **constructor parameter**, `Provider<Future<T>>` injects a provider over
  a raw `Future<T>` binding (a `@provides` returning `Future<T>` with no
  `@asynchronous`). The inner `Future<T>` is **preserved** (not unwrapped to
  `T`): `.get()` returns the `Future<T>`, which you `await`.
- As a **component entry point**, expose an async-resolved binding with
  `Provider<T>` (or `Future<T>`). Note the asymmetry: a `Provider<Future<T>>`
  *entry-point getter* over a **raw** `Future<T>` binding does **not** resolve
  (the generator unwraps it and looks for a bare `T`) — keep `Provider<Future<T>>`
  to constructor parameters.
- Use `Provider<T>` for lazy/optional dependencies and object pools; for a plain
  eager dependency, inject `T` directly.

## Assisted Injection

Use assisted injection when some constructor parameters come from the
dependency graph and others are provided at call time (runtime values).

### `@assistedInject` + `@assisted` + `@assistedFactory`

```dart
// 1. Define the factory interface
@assistedFactory
abstract class ProductCardFactory {
  ProductCard create(Product product);
}

// 2. Annotate the class constructor
class ProductCard extends StatelessWidget {
  @assistedInject
  const ProductCard(
    this._analyticsService,  // injected from the graph
    @assisted this.product,  // provided at call time
    {@assisted super.key},
  );

  final AnalyticsService _analyticsService;
  final Product product;
// ...
}

// 3. Expose the factory from the component
@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  ProductCardFactory get productCardFactory;
}

// 4. Use the factory
final card = component.productCardFactory.create(product);
```

**Rules:**

- The factory must be `abstract` and annotated with `@assistedFactory`.
- The constructor must be annotated with `@assistedInject`.
- Runtime parameters must be annotated with `@assisted`.
- The `@assisted` parameter types in the factory method must exactly match
  those in the `@assistedInject` constructor.
- The source file must declare `part '<file>.factory.dart';`.

## Application Architecture

inject.dart works naturally with layered architectures. Recommended layer
organization:

```
lib/
├── main.dart                # Component definition + app entry point
└── src/
    ├── data/
    │   ├── database.dart    # @inject or @provides — data layer
    │   └── api_client.dart  # @inject — network layer
    ├── domain/
    │   ├── repository.dart  # @inject — domain layer
    │   └── service.dart     # @inject @singleton — business logic
    └── ui/
        ├── view_model.dart  # @inject or @assistedInject — UI logic
        └── widget.dart      # @assistedInject — Flutter widgets
```

### Module Organization

Group providers by concern into focused modules:

```dart
@module
class NetworkModule {
  @provides
  @singleton
  Dio provideDio() => Dio(BaseOptions(baseUrl: 'https://api.example.com'));
}

@module
class DatabaseModule {
  @provides
  @singleton
  @asynchronous
  Future<Database> provideDatabase() => openDatabase('app.db');
}

@Component([NetworkModule, DatabaseModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  AppService get appService;
}
```

## Testing

inject.dart's constructor injection makes testing straightforward: create a
test component with a test module that replaces real implementations with
fakes.

### Test Component Pattern

```dart
// production component
@Component([NetworkModule, DatabaseModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  UserRepository get userRepository;
}

// test component — replaces real implementations
@Component([TestModule])
abstract class TestComponent {
  static const create = g.TestComponent$Component.create;

  @inject
  UserRepository get userRepository;

  @inject
  Database get database;
}

@module
class TestModule {
  @provides
  @singleton
  Database provideDatabase() => FakeDatabase();
}

class FakeDatabase implements Database {
  final _store = <String, dynamic>{};

  @override
  Future<void> save(String key, dynamic value) async =>
      _store[key] = value;

  @override
  Future<dynamic> load(String key) async => _store[key];
}
```

### Writing Tests

```dart
void main() {
  late TestComponent component;

  setUp(() {
    component = TestComponent.create();
  });

  test('UserRepository saves and loads users', () async {
    final repo = component.userRepository;
    final user = User(id: '1', name: 'Alice');

    await repo.save(user);
    final loaded = await repo.load('1');

    expect(loaded?.name, equals('Alice'));
  });
}
```

**Testing best practices:**

- Prefer `FakeDatabase` / stub implementations over mocks.
- Use `@singleton` in `TestModule` to ensure shared state within a test.
- Create a fresh component in `setUp()` to isolate each test.
- Test each layer in isolation — do not test through the full component graph
  unless writing an integration test.

### Golden Tests for Code Generation (`inject_generator`)

Tests for the code generator (`inject_generator`) use **golden file testing**
to validate generated output. Instead of fragile `contains()` assertions on
individual substrings, each test compares the full generator output against a
committed golden file using `equals()`.

**Directory structure:**

```
packages/inject_generator/test/golden/
├── fixtures/                       # Input Dart source files
│   ├── shared/                     # Fixtures used by multiple generators
│   │   ├── minimal_component.dart
│   │   ├── single_module_component.dart
│   │   └── ...
│   ├── code_generator/             # Fixtures only for CodeGenerator tests
│   ├── component_generator/        # Fixtures only for ComponentGenerator tests
│   └── provider_generator/         # Fixtures only for ProviderGenerator tests
└── expected/                       # Expected generated output (golden files)
    ├── code_generator/
    ├── component_generator/
    └── provider_generator/
```

Fixture files that are used by more than one generator go into `shared/`.
Fixtures specific to a single generator go into the matching subdirectory.

**Rules:**

- Each codegen scenario has a fixture file (input) and an expected file
  (golden output).
- Tests compare the **complete** generator output against the golden file.
- When a golden file does not exist yet, the test writes it and fails with a
  message to re-run — this prevents accidentally committing untested output.
- Set the `UPDATE_GOLDENS` environment variable to regenerate all golden
  files at once.
- Non-output tests (determinism checks, null returns, error paths) remain as
  focused unit tests — they do not produce golden files.
- Analysis tests, builder-mechanics tests, and logging tests stay
  assertion-based because they validate structured data, not generated code.
- `@Qualifier` annotations in fixture files must use `const` variable
  notation (e.g., `const brandName = Qualifier(#brandName);`), not inline
  constructor calls — see "Realistic Annotation Usage" above.

## Flutter Integration (`inject_flutter`)

Add the Flutter-specific package for widget-owned view model support:

```bash
flutter pub add inject_flutter
```

### `ViewModelFactory` + `ViewModelBuilder`

For `ChangeNotifier`-based view models that are owned by a specific widget:

```dart
// 1. Annotate the view model constructor
class CounterViewModel extends ChangeNotifier {
  @inject
  CounterViewModel(this._repository);

  final CounterRepository _repository;
  int count = 0;

  // Optional: an initializer that ViewModelBuilder runs once. May be async.
  Future<void> init() async {
    count = await _repository.current();
    notifyListeners();
  }

  Future<void> increment() async {
    count = await _repository.increment();
    notifyListeners();
  }
}

// 2. Expose a ViewModelFactory from the component
@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  ViewModelFactory<CounterViewModel> get counterViewModelFactory;
}

// 3. Call the injected factory in the widget — it returns a ViewModelBuilder.
//    The widget can stay a StatelessWidget; the factory owns the stateful parts.
class CounterPage extends StatelessWidget {
  const CounterPage({super.key, required this.factory});

  final ViewModelFactory<CounterViewModel> factory;

  @override
  Widget build(BuildContext context) {
    return factory(
      // init may be sync or async. An async init is awaited:
      // `loading` shows while it runs, `error` shows if it throws.
      init: (vm) => vm.init(),
      loading: const Center(child: CircularProgressIndicator()),
      error: (context, error, stackTrace) => Text('Failed: $error'),
      builder: (context, vm, child) => Text('Count: ${vm.count}'),
    );
  }
}
```

**Flutter integration rules:**

- `ViewModelFactory<T>` is only valid for `T extends ChangeNotifier`.
- Inject the **factory** (`ViewModelFactory<T>`), then **call it** —
  `factory(builder: …)` — to obtain the `ViewModelBuilder`. Never construct
  `ViewModelBuilder` by hand and never inject the view model directly.
- The `builder` callback receives `(context, viewModel, child)` — three
  arguments; `child` is the optional non-rebuilding subtree.
- View models provided via `ViewModelFactory` must **never** be `@singleton` —
  each `ViewModelBuilder` owns and disposes its own instance.
- The view model's **construction** dependency chain must be entirely
  **synchronous** — an async provider in the chain is a build-time diagnostic.
  (Asynchronous *work* belongs in `init`, not in the constructor.)
- `init` may be synchronous or return a `Future` (`FutureOr<void>`):
  - A synchronous (or absent) `init` builds the UI immediately.
  - An async `init` is awaited via a `FutureBuilder`: `loading` is shown while
    it runs, `error` (a `ViewModelErrorBuilder` — `(context, error, stack)`)
    when it throws. With no `error` builder, a failed init is reported through
    `FlutterError.reportError` rather than silently dropped.
- `ViewModelBuilder` owns the view model lifecycle: it is created and `init`
  runs once on widget creation, `dispose` runs once on widget removal.
- For shared long-lived state, inject a `@singleton` service into the view
  model — do not share the view model itself across widgets.

## Code Generation

### Build Runner Commands

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch --delete-conflicting-outputs

# Clean generated files
dart run build_runner clean
```

### Generated Code Conventions

inject.dart generates deterministic, readable code. Understanding the output
helps with debugging:

| Pattern                           | Generated for              |
|-----------------------------------|----------------------------|
| `ClassName$Component`             | `@component` class         |
| `static const create`             | Component factory          |
| `late final _foo = _createFoo();` | `@singleton` (sync)        |
| `Future<Foo>? _fooFuture;`        | `@singleton @asynchronous` |
| `Foo get() => _createFoo();`      | Non-singleton provider     |

### Importing Generated Files

Always import generated files with the `g` prefix:

```dart
import 'main.inject.dart' as g;

@component
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;
// ...
}
```

## Common Mistakes

### Synchronous getter over an asynchronous dependency chain

```dart
// ❌ WRONG — Config's chain is @asynchronous, but the getter is declared as T
@component
abstract class AppComponent {
  @inject
  Config get config; // build error: declared synchronous but chain is async
}

// ✅ CORRECT — declare the entry point as Future<T> (or Provider<T>) and await it
@component
abstract class AppComponent {
  @inject
  Future<Config> get config;
}
```

### Missing binding — no `@inject` on a class and no `@provides` in a module

```dart
// ❌ WRONG — AppService has no injection entry point
class AppService {
  AppService(this._repo); // no @inject
  final UserRepository _repo;
}

// ✅ CORRECT
class AppService {
  @inject
  AppService(this._repo);

  final UserRepository _repo;
}
```

### Using `as` casts instead of explicit types

```dart
// ❌ WRONG — inject.dart resolves types at build time; cast is unnecessary
final service = component.appService as ConcreteAppService;

// ✅ CORRECT — declare the concrete type in the component
@inject
ConcreteAppService get appService;
```

### Injecting `Future<T>` when you want `T`

```dart
// ❌ WRONG — if you want the resolved value, use @asynchronous
class Service {
  @inject
  Service(this._futureDb); // receives Future<Database>, not Database
  final Future<Database> _futureDb;
}

// ✅ CORRECT — mark the provider @asynchronous; inject.dart resolves it
@module
abstract class DbModule {
  @provides
  @asynchronous
  Future<Database> provideDb();
}

class Service {
  @inject
  Service(this._db); // receives Database
  final Database _db;
}
```

## Linting

Configure `analysis_options.yaml` with recommended rules:

```yaml
include: package:lints/recommended.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_final_fields
    - prefer_single_quotes
    - require_trailing_commas
```

Always run `dart analyze` after changes to verify zero warnings before
triggering a build.
