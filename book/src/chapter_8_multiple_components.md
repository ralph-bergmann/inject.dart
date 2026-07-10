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

## Outlook: subcomponents

A first-class mechanism for encapsulated child graphs is planned: a module
will be able to *install* a `@subcomponent` into the parent component, giving
the child access to all parent bindings while keeping the child's own bindings
private, with `@singleton` scoped per child instance. The seam stays the same
— you still just list a module. Until that lands, the patterns above are the
supported composition mechanisms.

## Cheat sheet

- One root component; more components only for lifecycle, environment, or test
  boundaries.
- `@singleton` is per component instance — share objects by passing them, not
  by re-listing modules.
- Installing a package = listing its module in `@Component([...])`; later
  modules override earlier ones.
- A module without a default constructor becomes a **required** `create`
  parameter — the channel for runtime config and shared objects.
- Root → feature wiring: `FeatureComponent.create(featureModule:
  FeatureModule(root.thing))`.
- The `@Component` lives in the app package; run `build_runner` where
  `@Component`s and `@assistedInject` files live.

[demo-pkg]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo/packages/counter_analytics
[demo-main]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/main.dart
[demo-test]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/test/view_model_test.dart
