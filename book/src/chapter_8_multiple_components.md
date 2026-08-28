# Composing Components and Multi-Package Projects

Most apps start — and many end — with a single root component. This chapter
covers what comes next: monorepos that split infrastructure into packages
(api, database, auth, analytics, …), and per-feature components that borrow
objects from a root component.

## One graph or many?

Components are **independent values**. There is no hidden registry and no
global state: creating a component wires exactly the bindings reachable from
its entry points, nothing else. Two components never share anything unless you
explicitly hand an object from one to the other.

Reasons to introduce a second component:

- **Per-feature or per-screen lifecycles** — a checkout flow that should build
  its object graph when entered and release it when left.
- **Different environments** — `ProdComponent` vs `StagingComponent` sharing a
  base module (see [Core Concepts](./chapter_4_core_concepts.md)).
- **Tests** — a test component that swaps real bindings for fakes (see
  [Testing](./chapter_6_testing.md)).

## Singletons are scoped per component instance

One rule to internalise before composing anything: `@singleton` guarantees a
single instance **within one component instance** — it is not app-global. Two
components that happen to list the same modules each build their *own*
singletons.

That means a second component must never re-list the root's modules in the
hope of "seeing" the root's objects — it would silently construct fresh
duplicates (a second database connection, a second HTTP client, …). Objects
that must be shared are *passed in*, as shown below.

## Marrying packages: modules are the seam

The typical Flutter monorepo splits infrastructure into packages — an api
package, a database package, an auth package. Each package ships its classes
plus a `@module`; the app installs a package by **listing its module in the
component**, exactly like a local module:

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

That is the whole integration story. The pieces:

- **Listing = installing.** Modules from other packages are listed like local
  ones, and module order keeps its meaning: a later module overrides an
  earlier one for the same `(type, qualifier)` key — so the app can append a
  module to reconfigure a package without touching it.
- **Module constructor parameters are the configuration channel.** A module
  without a default constructor becomes a *required* `create` parameter (see
  [The generated `create` factory](./chapter_4_core_concepts.md#the-generated-create-factory));
  that's how the base URL, database path, or app name enters the graph.
- **`@inject` classes work across packages without ceremony.** The generator
  resolves them wherever they live and emits their providers into the app's
  `.inject.dart` — library packages run no code generation and only depend on
  `inject_annotation`.
- **Interfaces bind by declared return type.** A package module typically
  exposes an interface (`@provides AnalyticsService provide() => ConsoleAnalyticsService(...)`);
  consumers inject the interface and tests override the binding with a fake.

Two rules of thumb:

- The `@Component` belongs in the package that can import **all** the
  implementations — in practice the app. Dependencies point app → package,
  never the other way around. When in doubt, give every package the same
  setup from [Installation](./chapter_2_installation.md); an unused dev
  dependency on the generator does no harm.
- A file declaring `@assistedInject` needs its `part '<file>.factory.dart';`
  generated *in its own package* — so run `build_runner` in packages that
  declare assisted constructors, too.

A package that is itself split into several internal modules doesn't have
to make the app list all of them: `@Module(includes: [...])` bundles them
behind one public umbrella module, so the app keeps listing exactly one
module per package. See the root README's "Umbrella modules" section for
the full mechanism.

A complete, runnable version ships with the repo: `flutter_demo`'s local
[`counter_analytics`][demo-pkg] package bundles an `AnalyticsService`
interface, a console implementation, an `@inject` consumer, and an
`AnalyticsModule` that [`MainComponent`][demo-main] lists like any local
module — configured at startup via
`create(analyticsModule: const AnalyticsModule('Counter App'))`, and swapped
for a no-op fake in [`view_model_test.dart`][demo-test].

## Per-feature components

The same module-instance mechanism connects *components*. A feature or screen
component lists a module whose **constructor carries the objects it borrows
from the root**, and the caller passes a configured instance built from the
root component's entry points:

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

- The compiler forces the wiring — `checkoutModule` is a required parameter.
- The feature component owns its own `@singleton`s and its own lifecycle;
  dropping the `checkout` reference releases the whole subgraph while the
  root lives on.
- The root never learns that feature components exist — the dependency arrow
  points root → feature only at the call site that wires them.

### The interface bridge

Instance-passing is simplest for a handful of already-built objects. When a
feature needs many objects, an async one, or must not statically reference
the root at all (see "Deferred features" below), give it a narrow
**interface** instead of a value:

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

Three properties fall out of this shape:

- **Lazy.** `BridgeModule.provideClient()` calls `deps.client` every time the
  checkout graph resolves that binding — nothing is captured eagerly at the
  `BridgeModule(root)` call.
- **Scope-preserving.** `@singleton` caching still happens in whichever graph
  owns the binding — the root, here — so the bridge never creates a second
  instance.
- **Async-transparent.** Declare the interface getter as `Future<T>` and the
  bridge's provider `@provides @asynchronous`; the checkout graph's own entry
  point becomes `Future<T>` too, and the `await` happens there — never at
  wiring time.

This is the inject.dart equivalent of Dagger's `@Component(dependencies:
[...])`, and of Hilt's dynamic-feature-module recipe, where the app defines
an `@EntryPoint` interface that the feature's own component depends on.
inject.dart's version keeps the same shape but inverts the awkward part of
that dependency: the feature defines the interface, the root implements it,
and the feature never names an app type at all.

## Session graphs: subcomponents

A module can also *install* a `@subcomponent` into the parent component,
giving the child graph access to every parent binding while keeping the
child's own bindings private, with `@singleton` scoped per child instance.
The seam stays the same as everything above — you still just list a
module:

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

Installing `SessionComponent` synthesizes a `SessionComponentFactory` and
binds it as an ordinary parent binding — inject it, call `create(...)`, get
a fresh session graph back. That factory lives in the `.factory.dart`
**part file** of whichever library declares the `@Subcomponent`, so that
file needs its own `part '<file>.factory.dart';` directive, same as any
`@assistedInject` file. See the root README's "Encapsulating subgraphs"
section for the full mechanism and the visibility/scope/async rules.

The synthesized factory only takes the subcomponent's own modules as
parameters. To hand a runtime value straight to the child graph — the
signed-in credentials, say — declare an explicit `@subcomponentFactory`
instead; every non-module parameter becomes an instance binding inside
the child graph:

```dart
@subcomponentFactory
abstract class SessionComponentFactory {
  SessionComponent create(Credentials credentials);
}
```

The hand-written factory replaces the synthesized one (so no
`.factory.dart` part file is involved for it); the classification rules
live in the root README's "Runtime values — `@subcomponentFactory`"
section. `bookshelf` uses exactly this shape to pass the login
`Credentials` into each session graph.

A session graph is the composition pattern this fits best: create the
subcomponent on login, drop the reference on logout, and every session
singleton it held goes with it — no explicit teardown, because it was
never a root-graph binding to begin with. [`examples/bookshelf`][bookshelf-readme]
is a complete, runnable app built around exactly this shape, on top of the
same shared-kernel and cross-package-binding patterns shown above.

In a Flutter app, `inject_flutter`'s `SubcomponentBuilder<T>` widget is the
lifecycle owner for that child graph — it calls `create` once when
mounted, hands the instance to `builder`, and calls an optional `dispose`
when removed from the tree, with a widget `Key` change as the only
recreation trigger. `bookshelf`'s `AuthGate`
([`lib/src/login/auth_gate.dart`][bookshelf-auth-gate]) shows the pattern:
it swaps between the login form and a `SubcomponentBuilder<SessionComponent>`
keyed on the signed-in `Credentials`, so logging out simply unmounts the
subtree instead of hand-rolling a `T? _session` field.

## Choosing a composition mechanism

|                    | Subcomponent | Bridge (instance-passing) | Bridge (interface) |
|--------------------|--------------|----------------------------|----------------------|
| Relationship       | Parent installs the child; the child sees every parent binding. | None — the two components are independent graphs. | None — the feature defines a contract, the root fulfills it. |
| Coupling           | The child graph is attached to the parent by installation. | The feature knows the concrete objects it was handed. | The feature knows only its own interface — never an app type. |
| When the value is available | Direct field access — parent and child are generated together, no indirection. | Captured **eagerly**, at the wiring call site. | Fetched **lazily**, per request, preserving the owning graph's scope. |
| Reach for it when  | Encapsulating an implementation detail, or a scope (a login session, a screen) that should be created and dropped as one unit. | A handful of already-built objects — the simplest possible wiring. | Many or asynchronous dependencies, a deferred-loaded feature, or migrating a Dagger `@Component(dependencies: [...])`. |

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
in the file that imports it — the interface is the one piece that must
stay outside the deferred feature library, while the feature component
itself is created from inside it.

The same interface is also the natural test seam: a fake `CheckoutDeps`
implementation drives the feature component in isolation, with no root
component involved at all.

## Cheat sheet

- One root component; more components only for lifecycle, environment, or test
  boundaries.
- `@singleton` is per component instance — share objects by passing them, not
  by re-listing modules.
- Installing a package = listing its module in `@Component([...])`; later
  modules override earlier ones.
- A package split into several internal modules can bundle them behind one
  public module with `@Module(includes: [...])`.
- A module without a default constructor becomes a **required** `create`
  parameter — the channel for runtime config and shared objects.
- Root → feature wiring: `FeatureComponent.create(featureModule:
  FeatureModule(root.thing))`.
- Root → feature wiring for many/async dependencies: define a narrow
  interface the root `implements`, and let a bridge module consume only
  that interface.
- Session or encapsulated child graph: install a `@subcomponent` via
  `@Module(subcomponents: [...])`; its factory is a normal parent binding
  — remember the subcomponent's own `part '<file>.factory.dart';` directive.
- The `@Component` lives in the app package; run `build_runner` where
  `@Component`s and `@assistedInject` files live.

[demo-pkg]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo/packages/counter_analytics
[demo-main]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/main.dart
[demo-test]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/test/view_model_test.dart
[bookshelf-readme]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/bookshelf/README.md
[bookshelf-auth-gate]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/bookshelf/lib/src/login/auth_gate.dart
