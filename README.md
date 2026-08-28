# inject.dart

**Compile-time dependency injection for Dart and Flutter.**

A small, declarative DI framework with strong Flutter integration.
Annotate your classes, run `build_runner`, and get fully wired,
type-safe code — no reflection, no runtime lookups, no global state.

## Why inject.dart?

- **Explicit dependencies.** Every requirement is a constructor
  parameter, visible right in the class's signature. Nothing is hidden
  in a global registry.
- **Compile-time validation.** Missing bindings, cycles, and
  type-mismatched wiring fail at build time — not when the user opens
  screen 7.
- **Zero runtime overhead.** The generator emits plain Dart that the
  compiler can fully optimise. No reflection, no `dart:mirrors`.
- **Refactor-safe.** Rename a class and the analyser shows you every
  wiring affected. No magic strings, no `Type` lookups at runtime.
- **Test-friendly.** Each component is just a value. Build it with test
  doubles in `setUp`, throw it away in `tearDown`. No global teardown
  required.
- **Flutter-native.** The optional `inject_flutter` package bridges
  generated providers to the widget lifecycle with a single typedef:
  `ViewModelFactory<T>`.

## Packages

| Package             | When to depend on it                                              |
|---------------------|-------------------------------------------------------------------|
| `inject_annotation` | Annotations and runtime types. Add it to **every** project.       |
| `inject_generator`  | The code generator. Add as a **dev dependency**.                  |
| `inject_flutter`    | `ViewModelFactory` and friends. Add it to **Flutter** projects.   |

# Installation

For **Flutter** projects:

```shell
flutter pub add inject_flutter inject_annotation dev:inject_generator dev:build_runner
```

For **Dart** projects (no Flutter integration):

```shell
dart pub add inject_annotation dev:inject_generator dev:build_runner
```

# Quick Start (Flutter)

We will build a counter app in four steps. The complete source lives in
[`examples/example/lib/main.dart`][example-main].

## 1. Define a view model

```dart
@inject
class CounterViewModel extends ChangeNotifier {
  int count = 0;

  void increment() {
    count++;
    notifyListeners();
  }
}
```

`@inject` adds the class to the dependency graph. The generator will
construct it whenever something asks for a `CounterViewModel` — and as
many times as needed, because no `@singleton` is attached.

## 2. Build a widget that asks for what it needs

```dart
class CounterPage extends StatelessWidget {
  @assistedInject
  const CounterPage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory,
  });

  final String title;
  final ViewModelFactory<CounterViewModel> viewModelFactory;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(
      builder: (context, viewModel, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text(
            '${viewModel.count}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: viewModel.increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

Two things are happening here:

- `@assistedInject` marks the constructor. Parameters tagged
  `@assisted` come from the *caller* at runtime (`key`, `title`); the
  rest is wired up by inject.dart. The factory used to invoke this
  constructor is **synthesised by the generator** — you do not have to
  declare it yourself.
- `ViewModelFactory<CounterViewModel>` is the Flutter bridge. It
  produces a `ViewModelBuilder` that creates a fresh view model on
  `initState`, rebuilds the subtree on `notifyListeners()`, and disposes
  the view model in `State.dispose`.

## 3. Wire it together with a component

```dart
import 'main.inject.dart' as g;

// `part` is needed because CounterPage's @assistedInject constructor
// lives in this same file — components themselves never require it.
part 'main.factory.dart';

void main() => runApp(
      MaterialApp(
        title: 'Counter',
        home: AppComponent.create().counterPageFactory.create(
              title: 'Counter',
            ),
      ),
    );

@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  CounterPageFactory get counterPageFactory;
}
```

`@component` declares the root of the dependency graph. The generator
produces a concrete class `AppComponent$Component` in `main.inject.dart`
that knows how to build every binding the component asks for —
including the synthesised `CounterPageFactory` from
`main.factory.dart`.

The `static const create` alias hides the generated class name from your
call sites. Most apps never have to import the generated files outside
of this single `as g` line.

## 4. Generate the code and run

```shell
dart run build_runner build
flutter run
```

That is the entire counter app. For a slightly richer version that
also shows `@module` and a separate `MaterialApp` widget, see
[`examples/example/lib/main.dart`][example-main].

# AI coding assistants

## Agent Skills

For agents that support the [Agent Skills][agentskills] format (Claude Code and
others), inject.dart provides task-focused skills under [`skills/`][skills-dir]
— each teaches *how* to perform one concrete DI task. Install with either tool:

```shell
# Node tool — installs straight from the GitHub repo
npx skills add https://github.com/ralph-bergmann/inject.dart/tree/master/packages/inject_annotation/skills --skill '*' --agent universal
```

```shell
# Dart tool (https://pub.dev/packages/skills) — discovers skills from your
# dependency tree and configured GitHub registries, into your IDE's skills dir
dart pub global activate skills
skills get
```

| Skill                                                        | Use it to…                                                                                                        |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| [`inject_annotation-setup-di`][skill-setup]                  | Add `build_runner` + inject.dart and scaffold the root component (from scratch).                                  |
| [`inject_annotation-add-injectable`][skill-injectable]       | Make a class injectable with `@inject` and expose it; `@singleton`.                                               |
| [`inject_annotation-create-module`][skill-module]            | Provide third-party / configured types with a `@module` (`@provides`, `@asynchronous`, `Qualifier`).              |
| [`inject_annotation-add-assisted-injection`][skill-assisted] | Mix injected and runtime parameters with `@assistedInject` / `@assisted` / `@assistedFactory`.                    |
| [`inject_annotation-inject-provider`][skill-provider]        | Inject `Provider<T>` for lazy or multiple instances.                                                              |
| [`inject_annotation-add-provision-listener`][skill-listener] | Observe provisioning with `ProvisionListener<T>` + `@provisionListener`.                                          |
| [`inject_annotation-flutter-view-model`][skill-viewmodel]    | Bind a `ChangeNotifier` view model to a widget with `ViewModelFactory` / `ViewModelBuilder` (sync or async init). |
| [`inject_annotation-write-tests`][skill-tests]               | Test injected code with a test component + test module + fakes.                                                   |

Together they cover every annotation in `inject_annotation` (`@component`,
`@module`, `@inject`, `@provides`, `@singleton`, `@asynchronous`, `Qualifier`,
`@assistedInject` / `@assisted` / `@assistedFactory`, `@provisionListener`), the
runtime contracts `Provider<T>` and `ProvisionListener<T>`, and the
`inject_flutter` view-model API.

## Core rule every skill upholds

inject.dart is **constructor injection only** — "if it builds, it runs." A good
assistant never suggests service-locator patterns (`get_it`, `provider` as a
locator, or manual registries), and re-runs code generation after any
annotation change:

```shell
dart run build_runner build --delete-conflicting-outputs
```

## Development — validating the skills

The skills must stay true to the generator's *actual* behaviour, not assumptions
about it. The strongest check is to **run each skill** — have your AI assistant
carry out the task each skill teaches, then prove the result compiles and
generates correctly:

1. Create a temporary pure-Dart package `_scratch/` — a `pubspec.yaml` with
   `resolution: workspace`, `inject_annotation` as a dependency, and
   `build_runner` + `inject_generator` (plus `test` if you exercise the testing
   skill) as dev-dependencies.
2. Add `_scratch` to the `workspace:` list in the root `pubspec.yaml`.
3. Inside `_scratch/`, **follow each skill to perform its task** — execute the
   skill as a user would, don't copy snippets out of it: `inject_annotation-setup-di` to
   scaffold the component, `inject_annotation-add-injectable` for a service,
   `inject_annotation-create-module` to provide a configured / `@asynchronous` /
   `Qualifier`-ed type, then `inject_annotation-add-assisted-injection`,
   `inject_annotation-inject-provider`, `inject_annotation-add-provision-listener`, and
   `inject_annotation-write-tests`. (The Flutter-only `inject_annotation-flutter-view-model`
   is exercised in a Flutter package — `examples/flutter_demo` already runs it
   and stays green.)
4. Run `dart pub get`, then inside `_scratch/`: `dart run build_runner build`
   and `dart analyze`.
5. Confirm the build writes outputs and `dart analyze` reports **No issues
   found!** — i.e. following the skills produced code that **compiles** and
   generates correctly. Skim the generated `*.inject.dart` to confirm the wiring
   matches what each skill claims.
6. Delete `_scratch/` and revert the `pubspec.yaml` edit.

A prompt you can hand your AI tool verbatim:

> With the inject.dart skills installed, create a temporary pure-Dart workspace
> member `_scratch/` and **follow each skill to carry out its task** (set up DI,
> add an injectable, create a module, assisted injection, inject a `Provider`,
> add a provision listener, write a test) — don't copy code out of the skills,
> run them. Add `_scratch` to the root `pubspec.yaml` `workspace:` list, run
> `dart pub get`, then `dart run build_runner build` and `dart analyze` inside
> it. Confirm the build writes outputs, `dart analyze` reports "No issues
> found!", and the generated code compiles and matches what each skill describes.
> Show me the output, then remove `_scratch/` and revert the `pubspec.yaml`.
> (Validate the Flutter view-model skill against `examples/flutter_demo`.)

# Features

## Constructor injection — `@inject`

Annotate the class (or a specific constructor) and the generator will
take care of constructing it whenever something asks for that type:

```dart
@inject
class UserService {
  UserService(this._client);
  final http.Client _client;
}
```

All constructor parameters become dependencies. Inject.dart resolves
them recursively from other `@inject` classes or from modules.

## Modules and `@provides`

For types you do not own (third-party classes), or types that need
custom construction logic, declare a `@module` with `@provides`
methods:

```dart
@module
class NetworkModule {
  @provides
  @singleton
  http.Client provideHttpClient() => http.Client();

  @provides
  UserService provideUserService(http.Client client) =>
      UserService(client);
}
```

Then list the module on the component:

```dart
@Component([NetworkModule])
abstract class AppComponent { /* ... */ }
```

A module's `@provides` methods can themselves take dependencies — the
generator wires them automatically.

### Passing module instances to `create`

The generated component factory accepts one **named parameter per
module** listed in `@Component([...])`, in declaration order:

- a module with a public no-arg constructor becomes an *optional*
  parameter — `create()` constructs it for you when omitted;
- a module whose constructor takes parameters becomes a **`required`**
  parameter — you build the instance and pass it in.

```dart
@module
class DbModule {
  DbModule(this.path);
  final String path;

  @provides
  @singleton
  Database provideDb() => Database.open(path);
}

// Generated signature: create({required DbModule dbModule})
final component = AppComponent.create(dbModule: DbModule('app.db'));
```

Passing a pre-built module instance is the intended way to feed
**runtime values and externally-constructed objects** into the graph —
the inject.dart counterpart to Dagger's `@BindsInstance`. See
[Composing Components and Multi-Package Projects][book-composing] for
how the same mechanism connects a feature component to a root
component.

[book-composing]: https://ralph-bergmann.github.io/inject.dart/chapter_8_multiple_components.html

### Umbrella modules — `@Module(includes: ...)`

A library author shipping several internal modules can bundle them
behind one public "umbrella" module, so a consuming app only has to
list that one module instead of every module the library happens to
be split into internally:

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
```

```dart
// App code only ever sees MyLibraryModule.
@Component([MyLibraryModule])
abstract class AppComponent { /* ... */ }
```

`AppComponent.create()` gets every provider from `ApiModule` and
`DbModule` exactly as if the app had listed both directly — `includes`
is followed transitively (an included module can itself include more
modules) and a module reachable through more than one include path is
installed exactly once (the first-reached position in the include
traversal wins, which is what determines its place in the override
order), so diamond-shaped include graphs are safe. A cycle (a module
that transitively includes itself) is a compile-time error.

Included modules follow the same [override
order](#passing-module-instances-to-create) as directly-listed ones —
later entries win for a shared provider key — with one added rule: a
component's (or subcomponent's) own directly-listed modules always
take precedence over anything pulled in through `includes`. That
covers the overlap case too: a module that is both listed directly
and reachable through another listed module's `includes:` is
installed exactly once, in its directly-listed position — one
`create()` parameter, direct precedence. Because
included modules become ordinary named parameters on `create()` too,
tests can still override one for mocking even though the app never
lists it directly — `FakeApiModule` here extends `ApiModule`, so it
satisfies the parameter's declared type:

```dart
AppComponent.create(apiModule: FakeApiModule());
```

Two things follow from included modules still being ordinary `create()`
parameters: each included module class must stay **public** (an
included module can't be private, the same as any directly-listed
one), and if it has no usable no-argument constructor, its parameter
becomes **required** on the *component's* (or subcomponent's)
generated `create()` — the same `create()` that already takes a
parameter for the umbrella module itself; there is no separate
generated factory for the umbrella module. So `includes` hides the
*listing*, not the module classes themselves.
And when a module both provides its own bindings and includes another
module for the same key, the including module's own providers win
(they're flattened after their own includes), independent of the
direct-over-included rule above, which only concerns *other*
directly-listed modules.

`includes` and `subcomponents` (see "Encapsulating subgraphs" below)
are independent `@Module` parameters — an included module can declare
its own `subcomponents:`, and that subcomponent still installs
correctly on whichever component ultimately includes it.

## Shared instances — `@singleton`

Apply `@singleton` to an `@inject`ed class or a `@provides` method to
guarantee that a single instance is shared across the dependency
graph:

```dart
@inject
@singleton
class SessionStore { /* ... */ }
```

`identical(component.sessionStore, component.sessionStore)` is
guaranteed to be `true`.

## Named bindings — `@Qualifier`

When two providers return the same type, distinguish them with a
`@Qualifier`:

```dart
const baseUrl = Qualifier(#baseUrl);
const oauthUrl = Qualifier(#oauthUrl);

@module
class UrlModule {
  @provides
  @baseUrl
  String provideBaseUrl() => 'https://api.example.com';

  @provides
  @oauthUrl
  String provideOAuthUrl() => 'https://auth.example.com';
}

@inject
class ApiClient {
  ApiClient(@baseUrl this.baseUrl, @oauthUrl this.oauthUrl);
  final String baseUrl;
  final String oauthUrl;
}
```

A `Qualifier` becomes part of the binding's identity. The generator
will reject duplicates and complain at build time if you forget one.

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

**Raw function types and raw record types without a typedef are not supported.**
The typedef is required for the generator to identify the dependency type
unambiguously.

One typedef is auto-synthesized by the generator and requires no `@provides`:
`ViewModelFactory<T extends ChangeNotifier>` (from `inject_flutter`) is a
typedef whose return type has a constructor with injectable extra parameters.
The generator synthesises the binding automatically — which is why you can
inject `ViewModelFactory<MyViewModel>` into a widget without writing a module
method for it.

## Asynchronous providers — `@asynchronous`

When a binding needs to be awaited (loading a config, opening a
database) annotate the `Future`-returning provider with
`@asynchronous`:

```dart
@module
abstract class DbModule {
  @provides
  @asynchronous
  @singleton
  Future<Database> provideDatabase() => Database.open('app.db');
}

@inject
class Repository {
  Repository(this._db);
  final Database _db; // Note: NOT Future<Database>
}
```

The `@asynchronous` annotation tells inject.dart to **resolve the
future before** providing the value. Consumers see plain `Database`,
not `Future<Database>`. Async-ness surfaces at the component boundary
instead: an entry point whose dependency chain contains an
`@asynchronous` binding is declared `Future<T>` and awaited there —
`create()` itself always stays synchronous.

If you actually want to inject the `Future` itself, leave the
annotation off — `Future<Database>` is then just another type.

## Encapsulating subgraphs — `@subcomponent`

Sometimes a group of bindings belongs together but should **not** be
visible to the rest of the graph — an HTTP stack whose client must
only be reachable through a public service, or a session graph that
has a shorter lifetime than the app. A subcomponent is an
encapsulated child graph: it can read every binding of its parent
component, but its own bindings stay invisible to the parent.

Declare the child graph with `@subcomponent` and install it through a
module — installing the module is the single integration point:

```dart
// The generated HttpSubcomponentFactory lands in this part file.
part 'network.factory.dart';

const internal = Qualifier(#internal);

@inject
@singleton
class Database {}

@module
class HttpModule {
  @provides
  @singleton
  HttpClient provideClient() => HttpClient();

  // Qualified — the parent re-export below binds the unqualified
  // RestApiService, and the same key must not exist on both sides.
  @provides
  @internal
  RestApiService provideApi(HttpClient client, Database db) =>
      RestApiService(client, db); // Database comes from the parent
}

@Subcomponent([HttpModule])
abstract class HttpSubcomponent {
  @internal
  RestApiService get apiService;
}

@Module(subcomponents: [HttpSubcomponent])
class NetworkModule {}

@Component([NetworkModule])
abstract class AppComponent {
  @inject
  Database get db;

  @inject
  HttpSubcomponentFactory get httpFactory;
}
```

inject.dart generates a `HttpSubcomponentFactory` (declared in the
`.factory.dart` part file of the file that declares the subcomponent —
note the `part` directive above) and binds it in the **parent**
graph. Inject it anywhere — a module provider, a class, or expose it
as an entry point — and call `create(...)` to get a fresh
subcomponent instance:

```dart
final component = AppComponent.create();
final httpGraph = component.httpFactory.create();
print(httpGraph.apiService); // but HttpClient stays private to the subgraph
```

How the two graphs relate:

| Aspect | Behaviour |
|---|---|
| Visibility | Child sees every parent binding; the parent sees **none** of the child's. A parent injection of a child-private type fails with a missing-binding error that names the subcomponent. |
| Scope | `@singleton` inside the subcomponent means **once per subcomponent instance**. Parent singletons stay app-wide and are shared by all child instances. |
| Re-binding | A subcomponent must not re-declare a binding key that the parent already provides — that is a build-time (codegen) error, not an override. |
| Async | `@asynchronous` propagates across the boundary: a child entry point whose chain reaches an async parent binding is declared `Future<T>`. `create(...)` itself always stays synchronous, exactly like components. |
| Runtime values | Through a module constructor — give the child module one and pass the instance to `create(httpModule: ...)` — or directly via `@subcomponentFactory`; see below. |
| Provision listeners | Component-local: a parent listener never observes child provisions, and vice versa — see "Observing provisions" below. |

Each `create(...)` call produces an independent instance, which makes
subcomponents a natural fit for session scopes: create the child
graph after login, drop the reference on logout, and all its
singletons are released with it. See [`examples/bookshelf`][bookshelf-readme]
for a complete, runnable app built around exactly that pattern — a
login flow that creates a `SessionComponent` holding session-private
credentials and a repository, released on logout. For the other ways
to split an app into several graphs — and when a plain second
component fits better — see the FAQ
"Can I have more than one component?" below.

In Flutter, `inject_flutter`'s `SubcomponentBuilder<T>` widget owns that
lifecycle for you: it calls `create` once when mounted (sync or `async`),
hands the instance to `builder`, and calls an optional `dispose` when
removed from the tree — a widget `Key` change is the only way to force a
new instance. Compose it *below* whatever branch point decides a
subcomponent should exist (a login/logout switch, say), so mounting it is
"create" and unmounting it is "dispose":

```dart
SubcomponentBuilder<SessionComponent>(
  key: ValueKey(credentials), // a new key forces a fresh session
  create: () => sessionFactory.create(credentials),
  builder: (context, session, _) => HomePage(session: session),
)
```

`examples/bookshelf`'s `AuthGate` is exactly this: it shows the login form
while signed out and mounts `SubcomponentBuilder<SessionComponent>` once
signed in.

To re-export a single binding to the parent, add a parent module
provider that consumes the subcomponent factory. One rule shapes the
pattern: the same binding key must not exist on both sides of the
boundary (see "Re-binding" above), and the re-export *is* a
parent-provided key. So the child binds the type under a different
key — the `@internal` qualifier in the example above (binding it
under a different type works too) — while the parent re-export binds
the plain, unqualified `RestApiService`:

```dart
@Module(subcomponents: [HttpSubcomponent])
class NetworkModule {
  @provides
  @singleton
  RestApiService provideApi(HttpSubcomponentFactory factory) =>
      factory.create().apiService;
}
```

### Runtime values — `@subcomponentFactory`

The synthesized `<Name>Factory` above only accepts the subcomponent's own
**modules** as parameters. To pass a runtime value straight in — a login
token, a request ID — without wrapping it in a module constructor, declare
an explicit factory instead:

```dart
@subcomponentFactory
abstract class HttpSubcomponentFactory {
  HttpSubcomponent create(String userId);
}
```

An `@subcomponentFactory` class must be `abstract` and declare exactly one
abstract method returning the installed `@subcomponent` type; it **replaces**
the synthesized factory for that subcomponent. Each parameter is classified
independently:

- A parameter whose type is one of the subcomponent's own declared modules
  behaves exactly like a synthesized factory's module parameter.
- Every other parameter is a **value parameter**: it becomes an instance
  binding in the child graph, injectable by any child binding under its
  `(type, qualifier)` — honoring `@Qualifier` and nullable-wrap resolution
  like any other binding. This is Dagger's `@BindsInstance` / Metro's
  `@Provides` factory-parameter equivalent.

A factory method may mix both kinds:

```dart
@subcomponentFactory
abstract class HttpSubcomponentFactory {
  HttpSubcomponent create(HttpModule module, String userId);
}
```

`create(...)` stays synchronous, exactly like the synthesized factory.

Related but different: `@assistedInject` (below) passes runtime
parameters into the construction of **one object** through a factory;
an `@subcomponentFactory` value parameter turns a runtime value into a
**binding** that the entire child graph can inject.

> **Out of scope (for now):** multi-level hierarchies — a subcomponent
> installing further subcomponents of its own; attempting it fails the
> build with "multi-level subcomponent hierarchies are not supported".
> (Set/Map multibindings are unrelated to subcomponents — inject.dart
> does not support them anywhere in the graph yet.)

## Runtime parameters — `@assistedInject`

Some constructor parameters are only known at the call site (a widget
key, a screen title, an item id). Mark them `@assisted` and let
inject.dart synthesise a factory for the rest:

```dart
class DetailPage extends StatelessWidget {
  @assistedInject
  const DetailPage({
    @assisted super.key,
    @assisted required this.itemId,
    required this.repository,
  });

  final String itemId;
  final Repository repository;
  // ...
}
```

The generator emits a corresponding factory in
`<your_file>.factory.dart`:

```dart
abstract class DetailPageFactory {
  DetailPage create({Key? key, required String itemId});
}
```

You then inject the factory wherever you build the page — the
caller supplies `itemId`, inject.dart supplies `repository`.

Assisted injection covers a runtime value that one object needs at
construction time. To make a runtime value a *binding* that a whole
child graph can inject, use "Runtime values — `@subcomponentFactory`"
above instead.

> **Need a custom factory shape?** Declare an `@assistedFactory`
> abstract class manually — e.g. to expose multiple `create` variants,
> use a different method name, or constrain the factory's name. The
> synthesised variant is just the default for the common case.

## Observing provisions — `@provisionListener`

`ProvisionListener` is a callback that fires after every matching
dependency is created. Use it for centralised logging, metrics, or for
tracking `Closeable`-like resources so a test teardown can release
them in one call.

```dart
class CreationLogListener implements ProvisionListener<ChangeNotifier> {
  int _count = 0;

  @override
  void onProvision(ChangeNotifier instance) {
    _count++;
    debugPrint('inject.dart -> $instance (#$_count)');
  }
}

@module
class AppModule {
  @provides
  @singleton
  @provisionListener
  CreationLogListener provideListener() => CreationLogListener();
}
```

Three annotations work together:

- `@provides` exposes the listener as a binding.
- `@singleton` ensures the same instance observes *every*
  provisioning.
- `@provisionListener` registers it as a provisioning hook.

The generic parameter narrows the scope:

- `ProvisionListener<ChangeNotifier>` fires only for `ChangeNotifier`
  subtypes.
- `ProvisionListener<Object>` (or just `ProvisionListener`) is a
  catch-all.

A listener must not retain references to instances whose lifecycle is
managed elsewhere (e.g. view models owned by `ViewModelFactory`),
otherwise the same object could be disposed twice. The pure-observer
implementation above is safe by construction.

**Scope with `@subcomponent`:** listeners are component-local and do
**not** cross the parent/child boundary. A listener registered in the
parent only observes provisions made by the parent graph; it does not
fire for bindings provisioned inside an installed subcomponent, even
though the subcomponent can read the parent's other bindings.
Conversely, a listener registered inside a subcomponent's own module
only observes that subcomponent's own provisions. There is currently
no mechanism for a parent listener to observe child provisions or
vice versa.

# Flutter integration — `ViewModelFactory`

`inject_flutter` adds one typedef and one widget for ViewModels, plus
`SubcomponentBuilder` (see "Encapsulating subgraphs — `@subcomponent`"
above) for owning a `@subcomponent` graph's lifecycle from a widget:

- `ViewModelFactory<T extends ChangeNotifier>` — a function that
  returns a `ViewModelBuilder<T>`. Inject it into your widget.
- `ViewModelBuilder<T>` — a `StatefulWidget` that:
    1. Calls `viewModelProvider.get()` in `initState` to obtain a fresh
       view model.
    2. Runs the optional `init` callback once — awaiting it when
       asynchronous (via a `FutureBuilder`), showing the optional `loading`
       widget while it runs and the optional `error` builder if it fails.
    3. Rebuilds via `ListenableBuilder` whenever the view model calls
       `notifyListeners()`.
    4. Calls `viewModel.dispose()` in `State.dispose`.

Two patterns matter:

```dart
// Default — fresh view model on initState, disposed on dispose.
viewModelFactory(
  builder: (context, viewModel, _) => /* widget */,
);

// With one-shot init (sync or async). An async init is awaited; `loading`
// shows until it completes.
viewModelFactory(
  init: (viewModel) => viewModel.load(),
  loading: const Center(child: CircularProgressIndicator()),
  builder: (context, viewModel, _) => /* widget */,
);
```

Use the optional `child` parameter when part of the subtree does not
depend on the view model — `ListenableBuilder` will pass it through
without rebuilding.

# How it works

`build_runner` runs **two** inject.dart builders, in sequence, over
your sources. The pipeline is declared in
[`packages/inject_generator/build.yaml`][build-yaml]:

1. **`factory_builder`** runs first. For every `.dart` file that
   declares `@assistedInject` constructors (or an explicit
   `@assistedFactory` abstract class), it emits
   `<name>.factory.dart` — a `part` file containing the factory
   contracts that the component will later implement. A file that
   declares a `@subcomponent` without an explicit
   `@subcomponentFactory` gets the same output: the synthesized
   `<Name>Factory` contract lands there. Files with none of these
   get no output.

2. **`inject_builder`** runs second. It picks each `@Component` as a
   starting point and walks the dependency graph from there — pulling
   in `@inject`-annotated classes, `@module` providers, and the
   factory contracts emitted in step 1. For each component it
   produces `<name>.inject.dart`, a library containing the concrete
   component class and every supporting `Provider`. Files without a
   `@Component` get no output.

So a given source file may end up with **zero, one, or both** of these
siblings, depending on what it contains:

| Source file declares…                          | Produces                                |
|------------------------------------------------|-----------------------------------------|
| only `@inject` classes / modules               | nothing — picked up via the component   |
| `@assistedInject` constructor / `@subcomponent` | `<name>.factory.dart`                   |
| `@Component`                                   | `<name>.inject.dart`                    |
| both of the above                              | both siblings                           |

```
What you write                    What the generator produces
------------------                -----------------------------
@inject                           _UserService$Provider
class UserService { ... }         (in <component>.inject.dart)

@assistedInject                   DetailPageFactory     (synthesised)
class DetailPage { ... }          (in <name>.factory.dart, a part file)
                                  _DetailPage$Factory   (implementation)
                                  _DetailPage$Provider  (lazy)
                                  (both in <component>.inject.dart)

@module                           wired into the
class NetworkModule {             component's constructor
  @provides ...                   (in <component>.inject.dart)
}

@Component([NetworkModule])       AppComponent$Component
abstract class AppComponent {     (concrete class with .create)
  ...                             (in <name>.inject.dart)
}
```

All wiring is statically determined. The generated component
constructor instantiates every `Provider` in dependency order and
caches singletons in `late final` fields. Calling
`AppComponent.create()` is an `O(n)` operation in the size of the
graph — no allocations after that until you actually call a getter.

[build-yaml]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_generator/build.yaml

# FAQ

### What does "compile-time" mean here?

The dependency graph is analysed and the wiring code is generated as
part of your build. There is no runtime configuration step, no service
registration, no `Type → Instance` map. The output is plain Dart that
behaves like hand-written code.

### Can I have more than one component?

Yes. Components are independent values. Which mechanism to reach for
depends on the relationship between the two graphs:

- **Encapsulated child graph, scoped to its own instance** — install a
  `@subcomponent` through a module (see "Encapsulating subgraphs —
  `@subcomponent`" above). The child reads every parent binding, but its
  own bindings stay invisible to the parent, and its `@singleton`s live
  and die with that one subcomponent instance. The natural fit for a
  session or per-screen scope you create and drop as a unit.
- **Independent graphs, a handful of shared objects** — the
  instance-passing bridge: the feature component lists a module whose
  constructor carries the objects it needs, and you pass a
  pre-configured instance to the feature component's `create` method:

  ```dart
  final root = RootComponent.create();
  final feature = FeatureComponent.create(
    featureModule: FeatureModule(root.db),
  );
  ```

- **Independent graphs, many/async objects, or no parent relationship at
  all** — the interface bridge: the feature defines a narrow interface
  for what it needs, the other component `implements` it, and a bridge
  module consumes only that interface. This is the inject.dart
  equivalent of Dagger's `@Component(dependencies: [...])`.

Note that `@singleton` is scoped **per component instance** — a second
component that merely lists the same modules builds *fresh* singletons
of its own; both bridge variants above obtain objects from the other
component instance instead of re-listing its modules, precisely to avoid
that. A library author with several
internal modules can also fold them behind one public module with
`@Module(includes: [...])`, so a consuming app only lists that one
module (see "Umbrella modules" above). The full "which one when"
guidance is in
[Composing Components and Multi-Package Projects][book-composing].

## Module Override Semantics

When two or more modules provide the same type (same type + same qualifier),
the **later module wins** — it overrides the earlier one. This follows the same
convention as [Dagger 2](https://dagger.dev/) and Hilt on Android, so the
mental model transfers directly.

```
@Component([ModuleA, ModuleB])   // ModuleB overrides ModuleA for shared keys
```

### Test-Mock Swap

Replace a production binding with a fake for component-level tests:

```dart
// Production
@Component([AppModule])
abstract class AppComponent {
  @inject Database get db;
}

// Test — TestModule.provideDb() shadows AppModule.provideDb()
@Component([AppModule, TestModule])
abstract class TestComponent {
  @inject Database get db;
}

@module
class TestModule {
  @provides
  Database provideDb() => FakeDatabase();
}
```

### Environment Swap

Declare one component per environment, sharing a common base module:

```dart
@Component([BaseModule, ProdModule])
abstract class ProdComponent {
  static const create = g.ProdComponent$Component.create;
  // ...
}

@Component([BaseModule, StagingModule])
abstract class StagingComponent {
  static const create = g.StagingComponent$Component.create;
  // ...
}
```

Wire the right one up at the build entry point (e.g., via a `--dart-define`
flag or separate `main_prod.dart` / `main_staging.dart` files).

### Third-Party Override

Override a binding from an imported library module without touching the
library itself — add your module last and it wins.

**Note on qualifiers:** A `@Qualifier` (or `@Named`) is part of the binding
key. `@Named('prod') String` and `@Named('test') String` are *different keys*
and will never override each other — both providers coexist in the component.

## Builder Configuration

Configure the generator via `build.yaml` under the `inject_generator|inject_builder` key:

```yaml
targets:
  $default:
    builders:
      inject_generator|inject_builder:
        options:
          nullable_duplicate_binding_policy: error  # error (default) | warn | allow
```

### `nullable_duplicate_binding_policy`

Controls what happens when both a nullable (`Foo?`) and a non-nullable (`Foo`)
binding exist for the **same type and qualifier** in the dependency graph.

| Value               | Behaviour                                                                                                                                    |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `error` *(default)* | Hard build error. The second binding is discarded to minimise downstream noise. Having both variants is almost always a programming mistake. |
| `warn`              | Both bindings are kept and both providers are generated. A `WARNING` diagnostic is emitted on the second binding.                            |
| `allow`             | Both bindings are kept silently — identical to the behaviour before this policy was introduced. Use for gradual migration.                   |

**Qualifier-aware:** The policy only fires when the qualifier is also identical.
`@prod Foo` and `Foo?` (unqualified) are *different keys* and are never flagged.

### `debug_graph`

Prints a formatted dependency-graph tree to the build log for each validated
component. Off by default — enable temporarily when you want to understand a
complex graph without reading the generated `.inject.dart` line by line.

```yaml
targets:
  $default:
    builders:
      inject_generator|inject_builder:
        options:
          debug_graph: true
```

The output is printed **per component** directly to stdout and is visible in
every normal build — no `--verbose` flag required:

```bash
dart run build_runner build
```

> If your source files haven't changed since the last build, `build_runner`
> skips all inputs and nothing is printed. Run a clean first:
>
> ```bash
> dart run build_runner clean
> dart run build_runner build
> ```

Example for a Coffee component with a shared `Heater` dependency:

```
[inject_generator] Dependency graph for CoffeeShop:
  CoffeeShop
  ├── Brewer (@singleton, @async)
  │   └── Heater...
  └── Grinder
      └── Heater...

  (shared bindings — each appears in the tree above as <name>...)
  Heater (@singleton, injected by: Brewer, Grinder)
```

**Annotation glossary:**
- `@singleton` — the binding is declared `@singleton`.
- `@async` — the binding is directly or transitively asynchronous (short for `@asynchronous`).
- `@<qualifier>` — the binding carries a qualifier (e.g. `@brand` for `const brand = Qualifier(#brand)`).
- `<TypeName>...` — shared node (≥ 2 receivers); full details in the shared-bindings block below the tree.
- `injected by: A, B` — lists every node that depends on this shared binding (in the shared block).
- `… (depth limit reached)` — dependency chain exceeded 20 levels (cycle validator would normally catch this first).

**Shared-bindings block:** When a node is injected by two or more other nodes it
appears in the main tree as `TypeName...` (no annotations, no sub-tree). Its
full annotation set, receiver list, and own dependencies are shown once in the
`(shared bindings …)` block that follows the main tree.

**No file output.** The tree is printed to the build console only and is not
written to any generated file.

**No performance impact when disabled** (`debug_graph: false` or absent). The
`GraphPrinter` is never instantiated in that case.

### How do I test a class that uses inject.dart?

You usually do not. Construct the class directly with whatever fakes
you want — every constructor parameter is explicit, so no DI framework
is involved at the unit-test level. If you want to test a whole
component, use the **module override pattern** described above — build
an alternate `@module` that provides fakes and list it last in
`@Component([..., TestModule])`. Listing it is enough when the module
has a no-arg constructor; if the fake needs per-test configuration,
give the module a constructor parameter and pass a pre-built instance
to the component's `create` method (see
[Passing module instances to `create`](#passing-module-instances-to-create)).

# Development

```shell
cd packages/inject_generator && dart test
```

Code-generation tests compare full generator output against golden
files. To regenerate after intentional changes:

```shell
cd packages/inject_generator && UPDATE_GOLDENS=1 dart test
```

Or for a single test file:

```shell
cd packages/inject_generator && \
  UPDATE_GOLDENS=1 dart test test/code_generation/code_generator_test.dart
```

# Links

- Repository: <https://github.com/ralph-bergmann/inject.dart>
- Issue tracker: <https://github.com/ralph-bergmann/inject.dart/issues>
- Documentation site: <https://ralph-bergmann.github.io/inject.dart/>

Contributions are welcome — feel free to open a PR.

[example-main]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/example/lib/main.dart
[bookshelf-readme]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/bookshelf/README.md
[agentskills]: https://agentskills.io/specification
[skills-dir]: https://github.com/ralph-bergmann/inject.dart/tree/master/packages/inject_annotation/skills
[skill-setup]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-setup-di/SKILL.md
[skill-injectable]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-add-injectable/SKILL.md
[skill-module]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-create-module/SKILL.md
[skill-assisted]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-add-assisted-injection/SKILL.md
[skill-provider]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-inject-provider/SKILL.md
[skill-listener]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-add-provision-listener/SKILL.md
[skill-viewmodel]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-flutter-view-model/SKILL.md
[skill-tests]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-write-tests/SKILL.md
