# AI rules for inject.dart

You are an expert in Dart and Flutter development with inject.dart, a
compile-time dependency injection (DI) library. Help developers build correct,
maintainable, testable applications with its annotations and build-time code
generation.

inject.dart promises: "If it builds, it runs." The generator validates the whole
dependency graph at build time, so missing bindings, circular dependencies, and
qualifier conflicts fail the build instead of crashing at runtime. Every
suggestion you make must keep that guarantee.

## Interaction guidelines

* Assume the user is a Dart or Flutter developer who may know service-locator
  patterns (get_it, riverpod) but is new to compile-time DI.
* If a request is ambiguous, ask whether the project is pure Dart or Flutter,
  and whether the dependency is synchronous or asynchronous.
* Never suggest service-locator patterns. That rules out `get_it`, `provider`
  used as a service locator, and manual `ServiceLocator` classes. inject.dart is
  constructor injection only: dependencies are explicit, and nothing is looked
  up at runtime.
* Whenever annotations are added or changed, remind the user to run the
  `build_runner` command.

## Setup

### Adding dependencies

```bash
# Dart project
dart pub add inject_annotation
dart pub add dev:inject_generator dev:build_runner

# Flutter project
flutter pub add inject_annotation
flutter pub add dev:inject_generator dev:build_runner
```

### Running code generation

After you add or change annotated classes, always run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For watch mode during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Generated files

inject.dart generates two types of files:

| File                  | Builder        | Purpose                      |
|-----------------------|----------------|------------------------------|
| `<name>.inject.dart`  | LibraryBuilder | Component implementation     |
| `<name>.factory.dart` | PartBuilder    | Assisted injection factories |

Always import `.inject.dart` files with a prefix to separate generated code from
hand-written code:

```dart
import 'main.inject.dart' as g;
```

## Core concepts

### The dependency graph

inject.dart builds the complete dependency graph at build time and resolves
every required type statically. If a binding is missing, the build fails, so the
app never starts in a broken state.

### Constructor injection

inject.dart uses constructor injection only. Declare dependencies as constructor
parameters and never look them up in a registry.

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

## Annotation reference

### `@component` / `@Component([Module1, Module2])`

Marks an abstract class as the root of the dependency graph. A component exposes
the objects that the application needs.

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

Rules:

- The class must be `abstract`.
- Components declare no constructors. `@inject` and `@assistedInject`
  constructors belong on injectable classes, never on a component class. The
  generated `create` factory is the only way to instantiate a component.
- Entry points are abstract getters or abstract methods. `@inject` on them is
  optional, because the generator treats an abstract getter on a component as an
  entry point either way. The examples always add `@inject`; do the same for
  clarity and consistency. Getters inherited from an `implements` clause count
  too: a component that `implements SomeInterface` gets `SomeInterface`'s
  abstract getters as entry points without re-declaring them.
- The static `create` reference points to the generated implementation.
- The generated `create` factory takes one named parameter per module, in
  `@Component([...])` declaration order. A parameter is optional when the module
  has a public no-arg constructor (it falls back to `Module()`), and `required`
  otherwise. The supported way to feed runtime values or externally constructed
  objects into the graph is to pass a pre-built module instance. This includes
  objects from another component (root-to-feature wiring).
- Root-to-feature wiring has two shapes. For a handful of objects, pass each
  already-built object through a module constructor, as above. For many objects,
  for async objects, or when the two components have no parent/child
  relationship, define a narrow interface that the other component `implements`
  and have the module consume only that interface. This is the equivalent of
  Dagger's `@Component(dependencies: [...])`. See "Interface bridge" below.
- For an encapsulated child graph, use `@subcomponent` /
  `@Module(subcomponents: ...)` below instead of a second independent
  `@Component`. Such a child reads every parent binding but keeps its own
  bindings private and scoped to its own instance.
- Module list order matters: later modules override bindings from earlier ones.

### `@module`

Marks a class as a collection of providers. Use modules to provide third-party
types or to control how instances are created.

```dart
@module
class NetworkModule {
  @provides
  HttpClient provideHttpClient() =>
      HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
}
```

Rules:

- Annotate provider methods with `@provides`.
- The generator injects method parameters from the graph.
- Register modules on the component: `@Component([NetworkModule])`.

### `@Module(includes: [...])`

Folds another module's providers into this one, transitively. A library author
can bundle several internal modules behind one public "umbrella" module, so a
consuming app lists only that one module.

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

Rules:

- `includes` is followed transitively: an included module can include more
  modules. A module reachable through more than one include path is installed
  exactly once, so diamond-shaped include graphs are safe. The first-reached
  position in the include traversal sets the module's place in the override
  order. A module that transitively includes itself is a build error.
- A component's or subcomponent's directly listed modules always take precedence
  over anything pulled in through `includes`. When a module both provides its
  own bindings and includes another module for the same key, the including
  module's own providers win.
- Included modules are still ordinary `create()` parameters. Each included
  module class must stay public, like a directly listed one. An included module
  with no usable no-arg constructor becomes a `required` parameter on the
  generated `create()` of the component or subcomponent. The umbrella module has
  no generated factory of its own.
- `includes` and `subcomponents` (below) are independent `@Module` parameters,
  so an included module can declare its own `subcomponents:`.

### `@subcomponent` / `@Module(subcomponents: [...])`

Marks an abstract class as an encapsulated child graph, installed into a parent
component through a module. The child can read every binding of the parent. The
parent can see the child's own bindings only when a module provider explicitly
re-exports one.

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

Rules:

- Installing a subcomponent via `subcomponents:` synthesises a `<Name>Factory`
  class and binds it as an ordinary parent binding. Inject it anywhere in the
  parent graph and call `create(...)` for a fresh child instance.
- The synthesised factory goes into the `.factory.dart` part file of the library
  that declares the `@Subcomponent`. That file needs its own
  `part '<file>.factory.dart';` directive, like an `@assistedInject` file.
- `@singleton` inside the subcomponent means once per subcomponent instance, not
  once per app. Parent `@singleton`s stay app-wide, shared by every child
  instance built from that parent.
- A subcomponent must not re-declare a binding key the parent already provides.
  That is a build error, not an override.
- `@asynchronous` propagates across the parent/child boundary: a child entry
  point whose dependency chain reaches an async parent binding must be declared
  `Future<T>`. `create(...)` itself always stays synchronous, like a component's.
- Multi-level hierarchies (a subcomponent installing its own subcomponents) are
  not supported.
- `@provisionListener` does not cross the parent/child boundary: a listener
  registered in one graph never observes provisions in the other.
- To re-export one child binding to the parent, give a parent module provider a
  dependency on the subcomponent factory and call `.create()` from it. The
  re-declare rule above applies here too: the child must bind the type under a
  different key, typically a `@Qualifier`, so the parent's unqualified binding
  does not collide. For the example above, add
  `const internal = Qualifier(#internal);`, annotate `HttpModule.provideApi` and
  the `apiService` entry point with `@internal`, then:

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

Replaces the synthesised `<Name>Factory` with an explicit one that also accepts
runtime values directly, without wrapping them in a module constructor:

```dart
@subcomponentFactory
abstract class HttpSubcomponentFactory {
  HttpSubcomponent create(HttpModule module, String userId);
}
```

Rules:

- The class must be `abstract` and declare exactly one abstract method that
  returns the installed `@subcomponent` type. It replaces the synthesised
  factory for that subcomponent.
- A parameter whose type is one of the subcomponent's own declared modules
  behaves like a synthesised factory's module parameter.
- Every other parameter is a value parameter. It becomes an instance binding in
  the child graph, injectable under its `(type, qualifier)` key with the same
  nullable-wrap resolution as any other binding. This is the equivalent of
  Dagger's `@BindsInstance`.
- A value parameter whose `(type, qualifier)` key collides with a binding the
  parent already provides is a build error. It counts as re-declaring a parent
  key, as a child module provider would.
- `create(...)` stays synchronous, like the synthesised factory.

### Interface bridge (cross-component access without a shared parent)

Bridge two components with a narrow interface instead of passing instances when
they have no parent/child relationship, when a feature needs many objects or an
async one, or when a feature must not statically reference the other component
at all (for example a deferred-loaded Flutter feature):

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

Rules:

- This is the inject.dart equivalent of Dagger's
  `@Component(dependencies: [...])` and of Hilt's `@EntryPoint`-based
  dynamic-feature-module recipe. The dependency points the other way: the
  feature defines the interface, the app implements it, and the feature never
  names an app type.
- The bridge is lazy. The bridge module's provider calls the interface getter
  every time the feature graph resolves that binding, and nothing is captured
  when the bridge module is constructed.
- The bridge preserves scope. `@singleton` caching happens in the graph that
  owns the binding (the app, above), so the bridge never creates a second
  instance.
- The bridge works with async bindings. Declare the interface getter as
  `Future<T>` and the bridge's provider as `@provides @asynchronous Future<T>`.
  The `await` happens where the feature graph resolves the entry point, never
  where the bridge module is constructed.
- A deferred-loaded feature must use this pattern instead of a `@subcomponent`.
  A subcomponent's factory is a type the parent module references directly,
  which (per Dart's loading-unit rules) would pull the whole feature into the
  base loading unit. The shared interface (`AppDeps` above) must live in a
  library both sides import normally, because Dart forbids using a deferred
  library's types in the file that imports it.
- To test the feature component, implement the interface with a fake. This side
  of the bridge needs no test parent component.

### `@inject`

Marks a class or a specific constructor as injectable, or a getter in a
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

Constructor selection rules:

- `@inject` may go on the class or on a constructor, including a named or
  factory constructor (`@inject factory Foo.create(...)` is valid).
- Class-level `@inject` with one constructor uses that constructor whatever its
  name. With multiple constructors it uses the unnamed one. If there is no
  unnamed constructor, that is a build error; annotate the intended constructor
  instead.
- A class may have multiple `@inject` constructors, but then each one must carry
  a distinct `@Qualifier`, and the qualifier symbol must be a valid Dart
  identifier.
- A class with no `@inject` anywhere is not injectable, and referencing it is a
  missing-binding build error. Use a `@module` for types you cannot annotate.

### `@provides`

Marks a method in a module as a provider for the dependency graph.

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

Creates one instance and reuses it for all dependents.

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

Rules:

- Singletons are scoped to the component instance.
- For synchronous singletons, inject.dart generates `late final`.
- For asynchronous singletons, inject.dart caches the `Future<T>`, not the
  resolved `T`, for concurrency safety.

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

Rules:

- `@asynchronous` is only valid on `@provides` methods in modules. Dart
  constructors cannot be async, so `@asynchronous` on an `@inject` class is
  meaningless. The generator must never read, store, or act on `@asynchronous`
  for `@inject`-annotated classes, and tests must never assert async behaviour
  for constructor-injected types.
- When the generator encounters `@asynchronous` on an `@inject` class, it must
  emit a diagnostic warning. The warning tells the user that the annotation has
  no effect on constructor-injected types and is only valid on `@provides`
  methods in `@module` classes.
- `create()` is always synchronous, because it constructs the component. Async
  resolution surfaces at the entry point: a component getter whose dependency
  chain is `@asynchronous` must be declared `Future<T>` (or
  `Provider<Future<T>>`), and you `await` that getter (or its `.get()` result).
  Declaring such a getter as a plain `T` is a build error: "declared synchronous
  but its dependency chain is asynchronous". Change the return type to
  `Future<T>`.
- To inject the `Future` itself, omit `@asynchronous` from the provider. The
  binding type then stays `Future<T>`, and the consumer awaits it explicitly.

### `@Qualifier(#name)` / custom qualifier constants

Distinguishes multiple bindings for the same type.

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

Rules:

- A `Qualifier` is a `const` instance of the `Qualifier` class.
- The binding key is the `(type, qualifier)` pair.
- A provider may have at most one `@Qualifier`.

### `@provisionListener` + `ProvisionListener<T>`

Registers an observer that is called after a dependency instance is provisioned.
Use it for logging, lifecycle tracking, or registering `Closeable`s. Implement
`ProvisionListener<T>` and provide it from a module with `@provisionListener`.

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

Rules:

- Annotate the provider method with `@provisionListener`. Its return type must
  implement `ProvisionListener`: either the concrete listener class (for example
  `CreationLogListener`) or the interface (`ProvisionListener<T>`). Any other
  return type is a build error.
- `@singleton` is optional, because provision listeners are treated as
  singletons automatically. Without `@singleton` the generator emits an info
  notice; adding it only silences that notice.
- The listened-to type comes from the `ProvisionListener<T>` the return type
  implements. `ProvisionListener<T>` fires only for instances assignable to `T`.
  `ProvisionListener<Object>` (or raw or `<dynamic>`) is a catch-all that fires
  for every provision. For a catch-all, prefer `ProvisionListener<Object>`: it
  lets `onProvision(Object instance)` type-check, while a raw
  `ProvisionListener` forces a `dynamic` parameter.
- Exceptions thrown from `onProvision` propagate unhandled to the caller.

## Lazy injection with `Provider<T>`

Inject `Provider<T>` instead of `T` to defer construction to call time or to get
multiple independent instances of a non-singleton. The generator supplies a
concrete `Provider<T>`; you never implement it.

```dart
class ConnectionPool {
  // Each `_create.get()` returns a fresh Connection (when not a @singleton).
  @inject
  ConnectionPool(this._create);

  final Provider<Connection> _create;

  Connection lease() => _create.get();
}
```

`Provider<T>` works in two places: as a constructor parameter (above) and as a
component entry-point getter:

```dart
@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  Provider<Connection> get connectionProvider; // lazy entry point
}
```

Rules:

- A `Provider<T>` resolves to the binding for its inner type `T`, and that
  binding must exist. A missing `T` is a build error, the same as for a direct
  `T`.
- Calling `.get()` invokes the provider each time. A `@singleton` returns the
  same cached instance, and a non-singleton returns a new instance per call.
- As a constructor parameter, `Provider<Future<T>>` injects a provider over a
  raw `Future<T>` binding (a `@provides` returning `Future<T>` with no
  `@asynchronous`). The inner `Future<T>` is preserved and not unwrapped to `T`:
  `.get()` returns the `Future<T>`, which you `await`.
- As a component entry point, expose a binding whose chain is `@asynchronous`
  with `Future<T>` or `Provider<Future<T>>`. `Provider<T>` over such a chain is
  a build error. Entry points differ from constructor parameters here: a
  `Provider<Future<T>>` entry-point getter over a raw `Future<T>` binding does
  not resolve, because the generator unwraps it and looks for a bare `T`. For a
  raw `Future<T>` binding, use `Provider<Future<T>>` only on constructor
  parameters.
- As a constructor parameter, `Provider<T>` needs a synchronous dependency
  chain. Over an `@asynchronous` chain, direct or transitive, it is a build
  error at the parameter, because `.get()` must return `T` synchronously.
  `Provider<Future<T>>` does not help: at a parameter it needs a raw
  `Future<T>` binding. At an `@inject` constructor, declare the parameter as
  `T`; the class then becomes async too.
- An injected parameter of an `@assistedInject` constructor or a `@provides`
  method cannot use `Provider<T>`: there it is a plain type that needs its own
  binding, and without one the build fails.
- Use `Provider<T>` for lazy or optional dependencies and object pools. For a
  plain eager dependency, inject `T` directly.

## Assisted injection

Use assisted injection when some constructor parameters come from the dependency
graph and others are provided at call time (runtime values).

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

Rules:

- The factory must be `abstract` and annotated with `@assistedFactory`.
- The constructor must be annotated with `@assistedInject`.
- Runtime parameters must be annotated with `@assisted`.
- The `@assisted` parameter types in the factory method must exactly match those
  in the `@assistedInject` constructor.
- The source file must declare `part '<file>.factory.dart';`.
- Injected parameters must have a synchronous dependency chain, because the
  factory cannot wait for them. Over an `@asynchronous` chain each one is a
  build error at the parameter. The same applies to the extra constructor
  parameters behind a typedef provider. Make the dependency synchronous, or
  pass the awaited value in as a factory parameter.

## Application architecture

inject.dart fits layered architectures. Recommended layout:

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

### Module organization

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

Constructor injection makes testing straightforward: create a test component
with a test module that replaces real implementations with fakes.

### Test component pattern

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

### Writing tests

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

Testing best practices:

- Prefer `FakeDatabase` or stub implementations over mocks.
- Use `@singleton` in `TestModule` to share state within a test.
- Create a fresh component in `setUp()` to isolate each test.
- Test each layer in isolation. Go through the full component graph only in an
  integration test.

### Golden tests for code generation (`inject_generator`)

Tests for the code generator (`inject_generator`) use golden file testing to
validate generated output. Each test compares the full generator output against
a committed golden file using `equals()`, which avoids fragile `contains()`
assertions on individual substrings.

Directory structure:

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

Fixture files used by more than one generator go into `shared/`. Fixtures
specific to a single generator go into the matching subdirectory.

Rules:

- Each codegen scenario has a fixture file (input) and an expected file (golden
  output).
- Tests compare the complete generator output against the golden file.
- When a golden file does not exist yet, the test writes it and fails with a
  message to re-run. This prevents accidentally committing untested output.
- Set the `UPDATE_GOLDENS` environment variable to regenerate all golden files
  at once.
- Non-output tests (determinism checks, null returns, error paths) stay focused
  unit tests and produce no golden files.
- Analysis tests, builder-mechanics tests, and logging tests stay
  assertion-based, because they validate structured data and not generated code.
- `@Qualifier` annotations in fixture files must use `const` variable notation
  (for example `const brandName = Qualifier(#brandName);`), not inline
  constructor calls.

## Flutter integration (`inject_flutter`)

Add the Flutter-specific package for widget-owned ViewModel support:

```bash
flutter pub add inject_flutter
```

### `ViewModelFactory` + `ViewModelBuilder`

For `ChangeNotifier`-based ViewModels that a specific widget owns:

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

Flutter integration rules:

- `ViewModelFactory<T>` is only valid for `T extends ChangeNotifier`.
- Inject the factory (`ViewModelFactory<T>`), then call it
  (`factory(builder: …)`) to obtain the `ViewModelBuilder`. Never construct
  `ViewModelBuilder` by hand and never inject the ViewModel directly.
- The `builder` callback receives three arguments, `(context, viewModel, child)`;
  `child` is the optional non-rebuilding subtree.
- ViewModels provided via `ViewModelFactory` must never be `@singleton`, because
  each `ViewModelBuilder` owns and disposes its own instance.
- The ViewModel's construction dependency chain must be entirely synchronous. An
  async provider in the chain is a build error. Asynchronous work belongs in
  `init`, not in the constructor.
- `init` may be synchronous or return a `Future` (`FutureOr<void>`):
  - A synchronous or absent `init` builds the UI immediately.
  - An async `init` is awaited via a `FutureBuilder`. `loading` is shown while
    it runs, and `error` (a `ViewModelErrorBuilder`, `(context, error, stack)`)
    when it throws. With no `error` builder, a failed init is reported through
    `FlutterError.reportError` instead of being dropped silently.
- `ViewModelBuilder` owns the ViewModel lifecycle: it creates the ViewModel and
  runs `init` once on widget creation, and runs `dispose` once on widget
  removal.
- For shared long-lived state, inject a `@singleton` service into the ViewModel.
  Do not share the ViewModel itself across widgets.

## Code generation

### `build_runner` commands

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch --delete-conflicting-outputs

# Clean generated files
dart run build_runner clean
```

### Generated code conventions

inject.dart generates deterministic, readable code. These patterns help when you
debug the output:

| Pattern                           | Generated for              |
|-----------------------------------|----------------------------|
| `ClassName$Component`             | `@component` class         |
| `static const create`             | Component factory          |
| `late final _foo = _createFoo();` | `@singleton` (sync)        |
| `Future<Foo>? _fooFuture;`        | `@singleton @asynchronous` |
| `Foo get() => _createFoo();`      | Non-singleton provider     |

### Importing generated files

Always import `.inject.dart` files with the `g` prefix:

```dart
import 'main.inject.dart' as g;

@component
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;
// ...
}
```

## Common mistakes

### Synchronous getter over an asynchronous dependency chain

```dart
// ❌ WRONG — Config's chain is @asynchronous, but the getter is declared as T
@component
abstract class AppComponent {
  @inject
  Config get config; // build error: declared synchronous but chain is async
}

// ✅ CORRECT — declare the entry point as Future<T> (or Provider<Future<T>>) and await it (or its .get() result)
@component
abstract class AppComponent {
  @inject
  Future<Config> get config;
}
```

### Missing binding: no `@inject` on a class and no `@provides` in a module

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

After changes, always run `dart analyze` and confirm zero warnings before you
start a build.
