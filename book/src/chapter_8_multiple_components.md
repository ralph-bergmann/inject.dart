# Scoping, Composing Components and Multi-Package Projects

Most apps start with a single root component, and many never need another. This
chapter covers what comes next: scopes that control how long an object lives
(including child scopes such as a login session), monorepos that split
infrastructure into packages (api, database, auth, analytics, …), and
per-feature components that borrow objects from a root component.

## One graph or many?

Components are independent values. There is no hidden registry or global state.
Creating a component wires exactly the bindings reachable from its entry points,
and two components share nothing unless you hand an object from one to the
other.

A second component makes sense in these cases:

- A per-feature or per-screen lifecycle, such as a checkout flow that builds its
  object graph when entered and releases it when left.
- Different environments: `ProdComponent` and `StagingComponent` sharing a base
  module (see [Core Concepts](./chapter_4_core_concepts.md)).
- Tests: a test component that swaps real bindings for fakes (see
  [Testing](./chapter_6_testing.md)).

## Scoping: how long an instance lives

In inject.dart, a scope is a component or subcomponent instance. There are no
scope annotations to declare. You open a scope by creating a component or
subcomponent, and you close it by dropping the reference. A scope holds:

- its `@singleton` instances, built once and kept for as long as the scope
  lives;
- the values passed to its `create(...)`, such as module instances or the
  signed-in `Credentials`;
- for a subcomponent, its own bindings, which code outside the child cannot
  reach.

An object without `@singleton` belongs to whoever asked for it. The graph builds
a new one on every request and keeps no reference, so a widget or another
object decides how long it lives. It still gets the dependencies of the scope
that built it: a `BooksViewModel` built by one login session gets that
session's `BookRepository`. If such an object outlives its scope, it keeps the
singletons it uses alive.

| Scope | Created by | Ends when | Holds |
|---|---|---|---|
| Root component | `MainComponent.create(...)` in `main()` | You drop the component, usually never | Singletons such as `ApiClient`, `Database`, `AuthRepository`, and the module instances passed to `create` |
| Subcomponent (child scope) | `create(...)` on a factory injected from the parent | You drop the child, for example on logout | Singletons such as the session's `BookRepository`, runtime values such as `Credentials`, and its private bindings |

`@singleton` therefore means one instance per scope, not one per app. Two
components that list the same modules each build their own singletons.

A second component must therefore never re-list the root's modules to "see" the
root's objects. It would silently construct duplicates (a second database
connection, a second HTTP client, …). Pass in the objects that must be shared,
as shown below. For a scope that should see everything the root has, use a
subcomponent (see [Child scopes: subcomponents](#child-scopes-subcomponents)).

## Marrying packages through modules

The typical Flutter monorepo splits infrastructure into packages, such as an api
package, a database package, and an auth package. Each package ships its classes
plus a `@module`. The app installs a package by listing its module in the
component, exactly like a local module:

```dart
// api package -----------------------------------------------------------
@module
class ApiModule {
  const ApiModule(this._baseUrl); // runtime config — no default constructor
  final String _baseUrl;

  @provides
  @singleton
  ApiClient provideApiClient() => ApiClient(baseUrl: _baseUrl);
}

// auth package -----------------------------------------------------------
@module
class AuthModule {
  // Providers freely depend on bindings from other packages' modules —
  // ApiClient comes from ApiModule above.
  @provides
  @singleton
  AuthRepository provideAuthRepository(ApiClient client) =>
      AuthRepository(client);
}

// app package ------------------------------------------------------------
@Component([ApiModule, AuthModule, AppModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;
}

void main() {
  final component = MainComponent.create(
    // ApiModule has no default constructor → the parameter is `required`;
    // the compiler forces the wiring. AuthModule and AppModule have default
    // constructors → optional, `create` builds them for you.
    apiModule: const ApiModule('https://api.example.com'),
  );
  runApp(component.myAppFactory.create());
}
```

Module order keeps its meaning across packages: a later module overrides an
earlier one for the same `(type, qualifier)` key. The app can therefore append a
module to reconfigure a package without touching it.

Module constructor parameters carry the configuration. A module without a
default constructor becomes a required `create` parameter (see
[The generated `create` factory](./chapter_4_core_concepts.md#the-generated-create-factory)),
which is how the base URL, database path, or app name enters the graph.

`@inject` classes work across packages with no extra setup. The generator
resolves them wherever they live and emits their providers into the app's
`.inject.dart`, so library packages run no code generation and depend only on
`inject_annotation`.

Interfaces bind by declared return type. A package module typically exposes an
interface (`@provides AnalyticsService provide() => ConsoleAnalyticsService(...)`).
Consumers inject the interface, and tests override the binding with a fake.

Two rules of thumb:

- The `@Component` belongs in the package that can import all the
  implementations, which in practice is the app. Dependencies point from the app
  to the packages, never the other way around. When in doubt, give every package
  the same setup from [Installation](./chapter_2_installation.md); an unused dev
  dependency on the generator does no harm.
- A file declaring `@assistedInject` needs its `part '<file>.factory.dart';`
  generated in its own package, so run `build_runner` in packages that declare
  assisted constructors too.

A package that is itself split into several internal modules doesn't have
to make the app list all of them: `@Module(includes: [...])` bundles them
behind one public umbrella module, so the app keeps listing exactly one
module per package. See the root README's "Umbrella modules" section for
the full mechanism.

A complete, runnable version ships with the repo: `flutter_demo`'s local
[`counter_analytics`][demo-pkg] package bundles an `AnalyticsService`
interface, a console implementation, an `@inject` consumer, and an
`AnalyticsModule` that [`MainComponent`][demo-main] lists like any local
module. The app configures it at startup with
`create(analyticsModule: const AnalyticsModule('Counter App'))`, and
[`view_model_test.dart`][demo-test] swaps it for a no-op fake.

## Per-feature components

The same module-instance mechanism connects *components*. A feature or screen
component lists a module whose constructor carries the objects it borrows from
the root, and the caller passes a configured instance built from the root
component's entry points:

```dart
@module
class CheckoutModule {
  const CheckoutModule(this.client);
  final ApiClient client;

  @provides
  ApiClient provideClient() => client;
}

@Component([CheckoutModule])
abstract class CheckoutComponent {
  static const create = g.CheckoutComponent$Component.create;

  @inject
  CheckoutViewModel get viewModel;
}

// When the checkout flow is entered:
final checkout = CheckoutComponent.create(
  checkoutModule: CheckoutModule(root.apiClient),
);
```

- `checkoutModule` is a required parameter, so the compiler forces the wiring.
- The feature component owns its `@singleton`s and its lifecycle. Dropping the
  `checkout` reference releases the whole subgraph while the root lives on.
- The root never learns that feature components exist. The only dependency from
  root to feature is at the call site that wires them.

### The interface bridge

Instance-passing is simplest for a handful of already-built objects. When a
feature needs many objects, an async one, or must not statically reference
the root at all (see "Deferred features" below), give it a narrow interface
instead of a value:

```dart
// checkout package — states what it needs, names no app type:
abstract class CheckoutDeps {
  ApiClient get client;
}

@module
class BridgeModule {
  const BridgeModule(this.deps);
  final CheckoutDeps deps;

  @provides
  ApiClient provideClient() => deps.client;
}

@Component([BridgeModule])
abstract class CheckoutComponent {
  static const create = g.CheckoutComponent$Component.create;

  @inject
  CheckoutViewModel get viewModel;
}

// root side — declares that it satisfies the interface. `client` is
// inherited from CheckoutDeps as an entry point; MainComponent does not
// re-declare it.
abstract class MainComponent implements CheckoutDeps {
  static const create = g.MainComponent$Component.create;
  // ...
}

// wiring:
final root = MainComponent.create(/* ... */);
final checkout = CheckoutComponent.create(bridgeModule: BridgeModule(root));
```

The bridge is lazy. `BridgeModule.provideClient()` calls `deps.client` every
time the checkout graph resolves that binding, and the `BridgeModule(root)` call
captures nothing.

It also preserves scope. `@singleton` caching still happens in the graph that
owns the binding (here, the root), so the bridge never creates a second
instance.

Async dependencies pass through it too. Declare the interface getter as
`Future<T>` and the bridge's provider `@provides @asynchronous`. The checkout
graph's own entry point becomes `Future<T>` as well, and the `await` happens
there and never at wiring time.

This is the inject.dart equivalent of Dagger's `@Component(dependencies:
[...])`, and of Hilt's dynamic-feature-module recipe, where the app defines
an `@EntryPoint` interface that the feature's own component depends on.
inject.dart's version keeps the same shape but inverts the awkward part of
that dependency: the feature defines the interface, the root implements it,
and the feature never names an app type at all.

## Child scopes: subcomponents

A subcomponent gives you a child scope inside the app-wide scope, such as one
scope per signed-in user or per screen. A module *installs* a `@subcomponent`
into the parent component. The child graph can access every parent binding,
its own bindings stay private, and `@singleton` is scoped per child instance.
You still just list a module:

```dart
@Subcomponent([SessionModule])
abstract class SessionComponent {
  BookRepository get bookRepository;
}

@Module(subcomponents: [SessionComponent])
class AppModule {}

@Component([AppModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  SessionComponentFactory get sessionFactory;
}
```

Installing `SessionComponent` synthesises a `SessionComponentFactory` and
binds it as an ordinary parent binding. Inject it, call `create(...)`, and you
get a fresh session graph. That factory lives in the `.factory.dart` part file
of the library that declares the `@Subcomponent`, so that file needs its own
`part '<file>.factory.dart';` directive, same as any `@assistedInject` file. See the root README's "Encapsulating subgraphs"
section for the full mechanism and the visibility/scope/async rules.

The synthesised factory only takes the subcomponent's own modules as
parameters. To hand a runtime value such as the signed-in credentials straight
to the child graph, declare an explicit `@subcomponentFactory` instead. Every
non-module parameter becomes an instance binding inside the child graph:

```dart
@subcomponentFactory
abstract class SessionComponentFactory {
  SessionComponent create(Credentials credentials);
}
```

The hand-written factory replaces the synthesised one (so no
`.factory.dart` part file is involved for it); the classification rules
are in the root README's "Runtime values: `@subcomponentFactory`"
section. `bookshelf` uses exactly this shape to pass the login
`Credentials` into each session graph.

### What `@singleton` means inside a subcomponent

Each child instance is its own scope:

- A `@singleton` from the subcomponent's own modules is built once per child
  instance. Every `create(...)` call starts a fresh scope, so each session gets
  its own `BookRepository`.
- A `@singleton` from the parent stays in the parent scope. All child instances
  share it, so every session uses the same `ApiClient`.
- An `@inject @singleton` class belongs to the parent when the parent graph
  already uses it, and all children share that instance. When only the child
  needs it, it belongs to the child and is built once per child instance.
- A subcomponent cannot override a parent binding. Declaring a binding key that
  the parent already provides is a build error.

Scopes nest one level deep today: the root and its subcomponents. A
subcomponent that installs its own subcomponents fails the build with
"multi-level subcomponent hierarchies are not supported". A session scope and
a per-screen scope are therefore siblings under the root, not nested inside
each other.

Subcomponents fit session graphs best. Create the subcomponent on login and drop
the reference on logout. Its singletons and the `Credentials` go with it once
nothing else references them. No explicit teardown is needed, because none of
it was ever stored in the root graph.
[`examples/bookshelf`][bookshelf-readme] is a complete, runnable app built around
this shape, on top of the same shared-kernel and cross-package-binding patterns
shown above.

### Child scopes in Flutter: `SubcomponentBuilder`

In a Flutter app, `inject_flutter`'s `SubcomponentBuilder<T>` widget ties a child
scope to a part of the widget tree. Mounting the widget opens the scope, and
unmounting it closes the scope. `bookshelf`'s `AuthGate`
([`lib/src/login/auth_gate.dart`][bookshelf-auth-gate]) shows the login case.
There, `SessionComponent` also exposes a `HomePageFactory`, so the home page and
its view model are built inside the session scope:

```dart
class _AuthGateState extends State<AuthGate> {
  Credentials? _credentials;

  @override
  Widget build(BuildContext context) {
    final credentials = _credentials;
    if (credentials == null) {
      return widget.loginPageFactory.create(
        onLoggedIn: (c) => setState(() => _credentials = c),
      );
    }
    return SubcomponentBuilder<SessionComponent>(
      key: ValueKey(credentials),
      create: () => widget.sessionFactory.create(credentials),
      builder: (context, session, _) => session.homePageFactory.create(
        onLogout: () => setState(() => _credentials = null),
      ),
    );
  }
}
```

- `create` runs once, when the widget is mounted. It may return a `Future`.
  The widget then shows `loading` while it runs and `error` if it fails.
- Only a new `Key` creates a new scope. Keying on the `Credentials` gives every
  login its own session, and other rebuilds keep the current one.
- Logging out sets `_credentials` to `null`, which unmounts the
  `SubcomponentBuilder` and closes the scope. Pass the optional `dispose`
  callback if the session holds resources you must release yourself.
  Otherwise dropping the reference is enough.

## Choosing a composition mechanism

|                    | Subcomponent | Bridge (instance-passing) | Bridge (interface) |
|--------------------|--------------|----------------------------|----------------------|
| Relationship       | Parent installs the child; the child sees every parent binding. | None: the two components are independent graphs. | None: the feature defines a contract, the root fulfills it. |
| Coupling           | The child graph is attached to the parent by installation. | The feature knows the concrete objects it was handed. | The feature knows only its own interface and never an app type. |
| Scope of `@singleton` | The child's singletons live once per child instance; the parent's are shared by all children. | The feature component has its own scope; borrowed objects keep the root's lifetime. | The feature component has its own scope; borrowed objects stay cached in the root. |
| When the value is available | Direct field access: parent and child are generated together, with no indirection. | Captured **eagerly**, at the wiring call site. | Fetched **lazily**, per request, preserving the owning graph's scope. |
| Reach for it when  | Encapsulating an implementation detail, or a scope (a login session, a screen) that should be created and dropped as one unit. | A handful of already-built objects; the simplest possible wiring. | Many or asynchronous dependencies, a deferred-loaded feature, or migrating a Dagger `@Component(dependencies: [...])`. |

### Deferred features and testing

A deferred-loaded feature library (Flutter's [deferred
components](https://docs.flutter.dev/perf/deferred-components), Dart's
`deferred as`) must use the bridge, not a subcomponent: a subcomponent's
factory is a type the parent module references directly, and per Dart's
[library-loading rules](https://dart.dev/language/libraries#lazily-loading-a-library),
any non-deferred reference to it pulls the whole feature into the base
loading unit regardless of a `deferred` import elsewhere. The shared
provision interface (`CheckoutDeps` above) has to live in a library both
sides import normally, since Dart forbids using a deferred library's types
in the file that imports it. The interface is the one piece that must stay
outside the deferred feature library; the feature component itself is created
from inside it.

The same interface also helps in tests: a fake `CheckoutDeps` implementation
drives the feature component in isolation, with no root component involved.

## Cheat sheet

- One root component; more components only for lifecycle, environment, or test
  boundaries.
- A scope is a component or subcomponent instance. It holds its singletons and
  the values passed to `create(...)`, and `@singleton` means one instance per
  scope. Share objects by passing them, not by re-listing modules.
- Install a package by listing its module in `@Component([...])`; later modules
  override earlier ones.
- A package split into several internal modules can bundle them behind one
  public module with `@Module(includes: [...])`.
- A module without a default constructor becomes a required `create` parameter,
  which is the channel for runtime config and shared objects.
- To wire a feature to the root: `FeatureComponent.create(featureModule:
  FeatureModule(root.thing))`.
- To wire a feature with many or async dependencies: define a narrow interface
  the root `implements`, and let a bridge module consume only that interface.
- Child scope (a session, a screen) or encapsulated child graph: install a
  `@subcomponent` via `@Module(subcomponents: [...])`. Its factory is a normal
  parent binding. Child singletons live once per child instance; parent
  singletons are shared. In Flutter, `SubcomponentBuilder` opens and closes the
  child scope together with its widget.
  Remember the subcomponent's own `part '<file>.factory.dart';` directive.
- The `@Component` lives in the app package; run `build_runner` where
  `@Component`s and `@assistedInject` files live.

[demo-pkg]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo/packages/counter_analytics
[demo-main]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/main.dart
[demo-test]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/test/view_model_test.dart
[bookshelf-readme]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/bookshelf/README.md
[bookshelf-auth-gate]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/bookshelf/lib/src/login/auth_gate.dart
