# inject.dart

**Compile-time dependency injection for Dart and Flutter.**

A small, declarative DI framework with strong Flutter integration.
Annotate your classes, run `build_runner`, and get fully wired,
type-safe code with no reflection, runtime lookups, or global state.

## Why inject.dart?

Every dependency is a constructor parameter, visible in the class's
signature, and nothing is hidden in a global registry.

Missing bindings, cycles, and type-mismatched wiring fail the build.
With a runtime framework, you would find them when the user opens
screen 7.

The generator emits plain Dart that the compiler can fully optimise, so
there is no runtime overhead and no reflection or `dart:mirrors`.
Refactoring is safer too: rename a class and the analyzer shows every
affected wiring, because nothing depends on magic strings or `Type`
lookups at runtime.

Each component is a value. In tests you build it with fakes in `setUp`
and throw it away in `tearDown`, with no global teardown.

Scoping follows the same idea. Each component or subcomponent instance is a
scope that holds its singletons and the values passed to its `create`. A
subcomponent adds a child scope, such as one per login session, whose
bindings stay private. Drop the child and everything it held goes with it,
while the app-wide singletons stay (see [Scoping][book-scoping]).

For Flutter, the optional `inject_flutter` package connects generated
providers to the widget lifecycle with a single typedef:
`ViewModelFactory<T>`.

## Packages

| Package             | When to depend on it                                              |
|---------------------|-------------------------------------------------------------------|
| `inject_annotation` | Annotations and runtime types. Add it to every project.           |
| `inject_generator`  | The code generator. Add as a dev dependency.                      |
| `inject_flutter`    | `ViewModelFactory` and friends. Add it to Flutter projects.       |

# Installation

For Flutter projects:

```shell
flutter pub add inject_flutter inject_annotation dev:inject_generator dev:build_runner
```

For Dart projects (no Flutter integration):

```shell
dart pub add inject_annotation dev:inject_generator dev:build_runner
```

# Quickstart (Flutter)

This section builds a counter app in four steps. The complete source is
in [`examples/example/lib/main.dart`][example-main].

## 1. Define a ViewModel

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

`@inject` adds the class to the dependency graph. The generator
constructs it whenever something asks for a `CounterViewModel`, as many
times as needed, because it has no `@singleton`.

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

- `@assistedInject` marks the constructor. `@assisted` parameters
  (`key`, `title`) come from the caller at runtime, and the rest come
  from the graph. The generator synthesises the factory that calls this
  constructor, so you never write it.
- `ViewModelFactory<CounterViewModel>` is the `inject_flutter` lifecycle
  bridge. It produces a `ViewModelBuilder` that creates a fresh ViewModel
  in `initState`, rebuilds the subtree on `notifyListeners()`, and
  disposes the ViewModel in `State.dispose`.

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
that knows how to build every binding the component asks for, including
the synthesised `CounterPageFactory` from `main.factory.dart`.

The `static const create` alias hides the generated class name from your
call sites. Most apps never have to import the generated files outside
of this single `as g` line.

## 4. Generate the code and run

```shell
dart run build_runner build
flutter run
```

For a slightly richer version that also shows `@module` and a separate
`MaterialApp` widget, see
[`examples/example/lib/main.dart`][example-main].

# AI coding assistants

## AI rules file

[`rules/rules.md`][rules-file] describes inject.dart in one document: the
annotations, the build steps, testing, and common mistakes. Copy it into the
file your assistant reads project rules from, such as `AGENTS.md` or
`CLAUDE.md`. You can drop the section on golden tests, which only matters when
you work on the generator itself.

## Agent Skills

For agents that support the [Agent Skills][agentskills] format (Claude Code,
Cursor and others), inject.dart provides task-focused skills under
[`skills/`][skills-dir]. Each skill teaches one concrete DI task. Install them in
one of three ways.

### With Dart, for any agent

Dart's [package skills][dart-package-skills] tool copies the skills that your
dependencies ship into your agent's skills directory, such as `.agents/skills/`.
Run it in a project that depends on `inject_annotation`:

```shell
dart run skills@ get -p inject_annotation
```

The skills come from the `inject_annotation` version your project uses, so run
the command again after you upgrade.

### In Claude Code

Add this repository as a plugin marketplace, then install the plugin:

```text
/plugin marketplace add ralph-bergmann/inject.dart
/plugin install inject-annotation@inject-dart
```

Claude Code adds the plugin name in front of each skill, for example
`/inject-annotation:inject-annotation-setup-di`. To get new versions of the
skills, turn on auto-update for the `inject-dart` marketplace in `/plugin`.

### In Cursor

Open **Customize**, choose **From GitHub Repository**, enter
`https://github.com/ralph-bergmann/inject.dart`, then install the
`inject-annotation` plugin. Teams can add the repository as a team marketplace
instead.

### The skills

| Skill                                                        | Use it to…                                                                                                        |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| [`inject-annotation-setup-di`][skill-setup]                  | Add `build_runner` + inject.dart and scaffold the root component (from scratch).                                  |
| [`inject-annotation-add-injectable`][skill-injectable]       | Make a class injectable with `@inject` and expose it; `@singleton`.                                               |
| [`inject-annotation-create-module`][skill-module]            | Provide third-party / configured types with a `@module` (`@provides`, `@asynchronous`, `Qualifier`).              |
| [`inject-annotation-add-assisted-injection`][skill-assisted] | Mix injected and runtime parameters with `@assistedInject` / `@assisted` / `@assistedFactory`.                    |
| [`inject-annotation-inject-provider`][skill-provider]        | Inject `Provider<T>` for lazy or multiple instances.                                                              |
| [`inject-annotation-add-provision-listener`][skill-listener] | Observe provisioning with `ProvisionListener<T>` + `@provisionListener`.                                          |
| [`inject-annotation-flutter-view-model`][skill-viewmodel]    | Bind a `ChangeNotifier` ViewModel to a widget with `ViewModelFactory` / `ViewModelBuilder` (sync or async init).  |
| [`inject-annotation-write-tests`][skill-tests]               | Test injected code with a test component + test module + fakes.                                                   |

Together they cover every annotation in `inject_annotation` (`@component`,
`@module`, `@inject`, `@provides`, `@singleton`, `@asynchronous`, `Qualifier`,
`@assistedInject` / `@assisted` / `@assistedFactory`, `@provisionListener`), the
runtime contracts `Provider<T>` and `ProvisionListener<T>`, and the
`inject_flutter` ViewModel API.

## The core rule

All of the guidance rests on one rule: inject.dart is constructor injection
only. "If it builds, it runs." A good assistant never suggests service-locator
patterns (`get_it`, `provider` used as a locator, or hand-rolled registries) and
re-runs code generation after every annotation change:

```shell
dart run build_runner build --delete-conflicting-outputs
```

## Validating the skills

The skills must match what the generator does. The strongest check is to run
each skill: have your AI assistant carry out the task each skill teaches, then
confirm that the result compiles and generates correctly.

1. Create a temporary pure-Dart package `_scratch/`. Its `pubspec.yaml` has
   `resolution: workspace`, `inject_annotation` as a dependency, and
   `build_runner` + `inject_generator` (plus `test` if you exercise the testing
   skill) as dev dependencies.
2. Add `_scratch` to the `workspace:` list in the root `pubspec.yaml`.
3. Inside `_scratch/`, follow each skill to perform its task the way a user
   would. Do not copy snippets out of it. Use `inject-annotation-setup-di` to
   scaffold the component, `inject-annotation-add-injectable` for a service,
   `inject-annotation-create-module` to provide a configured / `@asynchronous` /
   `Qualifier`-ed type, then `inject-annotation-add-assisted-injection`,
   `inject-annotation-inject-provider`, `inject-annotation-add-provision-listener`, and
   `inject-annotation-write-tests`. The Flutter-only `inject-annotation-flutter-view-model`
   needs a Flutter package: `examples/flutter_demo` already runs it and stays
   green.
4. Run `dart pub get`, then inside `_scratch/`: `dart run build_runner build`
   and `dart analyze`.
5. Confirm that the build writes outputs and `dart analyze` reports "No issues
   found!". That means following the skills produced code that compiles and
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

## Constructor injection: `@inject`

Annotate a class (or a specific constructor) and the generator wires it
wherever the type is needed:

```dart
@inject
class UserService {
  UserService(this._client);
  final http.Client _client;
}
```

All constructor parameters become dependencies, and the generator
resolves them recursively from other `@inject` classes or from modules.

## Modules and `@provides`

Declare a `@module` with `@provides` methods for types you do not own,
such as third-party classes and abstract interfaces, and for types that
need custom construction logic:

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

A `@provides` method can take dependencies of its own, and the generator
wires them automatically.

### Passing module instances to `create`

The generated `create` factory has one named parameter per module listed
in `@Component([...])`, in declaration order:

- A module with a public no-arg constructor becomes an optional
  parameter. If you omit it, `create` instantiates the module itself.
- A module whose constructor takes parameters becomes a `required`
  parameter. You build the instance and pass it in.

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

A pre-built module instance is the intended way to pass runtime values
and externally constructed objects into the graph (the inject.dart
counterpart to Dagger's `@BindsInstance`). See
[Scoping, Composing Components and Multi-Package Projects][book-composing]
for how the same mechanism connects a feature component to a root
component.

[book-composing]: https://ralph-bergmann.github.io/inject.dart/chapter_8_multiple_components.html
[book-scoping]: https://ralph-bergmann.github.io/inject.dart/chapter_8_multiple_components.html#scoping-how-long-an-instance-lives

### Umbrella modules: `@Module(includes: ...)`

A package split into several internal modules can bundle them behind
one public umbrella module, so the app lists only that one module:

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
`DbModule` exactly as if the app had listed both directly. `includes`
is followed transitively, so an included module can include more
modules. A module reachable through more than one include path is
installed exactly once, and the first-reached position in the include
traversal determines its place in the override order. Diamond-shaped
include graphs are therefore safe. A cycle (a module that transitively
includes itself) is a build error.

Included modules follow the same [override
order](#passing-module-instances-to-create) as directly listed ones: a
later module wins for the same `(type, qualifier)` key. One rule is
added: a component's (or subcomponent's) own directly listed modules
always take precedence over anything pulled in through `includes`. A
module that is both listed directly and reachable through another
listed module's `includes:` is installed exactly once, in its directly
listed position, with one `create()` parameter.

Included modules become ordinary named parameters on `create()` too, so
tests can still replace one with a fake even though the app never lists
it directly. `FakeApiModule` here extends `ApiModule`, so it satisfies
the parameter's declared type:

```dart
AppComponent.create(apiModule: FakeApiModule());
```

Each included module class must stay public, like any directly listed
module. If it has no usable no-arg constructor, its parameter becomes
required on the component's (or subcomponent's) generated `create()`,
the same `create()` that already takes a parameter for the umbrella
module itself. The umbrella module gets no separate generated factory.
So `includes` hides the listing, not the module classes themselves.

When a module both provides its own bindings and includes another
module for the same key, the including module's own providers win,
because they are flattened after their own includes. This is
independent of the direct-over-included rule above, which only concerns
other directly listed modules.

`includes` and `subcomponents` (see "Encapsulating subgraphs" below)
are independent `@Module` parameters. An included module can declare
its own `subcomponents:`, and that subcomponent still installs
correctly on whichever component ultimately includes it.

## Shared instances: `@singleton`

Add `@singleton` to an `@inject` class or a `@provides` method to
guarantee a single instance for the component's lifetime:

```dart
@inject
@singleton
class SessionStore { /* ... */ }
```

`identical(component.sessionStore, component.sessionStore)` is
guaranteed to be `true`.

There are no scope annotations: a `@singleton` lives as long as the
component or
subcomponent instance that owns its binding. For a shorter child scope,
such as one per login session, see "Encapsulating subgraphs" below.

## Named bindings: `@Qualifier`

When two providers return the same Dart type, a qualifier makes them
distinct:

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

A `@Qualifier` is part of the binding key. The generator rejects
duplicates and reports a build error if you forget one.

## Typedef dependencies

inject.dart supports typedef-wrapped function types and record types as
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

Raw function types and raw record types without a typedef are not supported.
The generator needs the typedef to identify the dependency type unambiguously.

The generator synthesises one typedef binding itself:
`ViewModelFactory<T extends ChangeNotifier>` (from `inject_flutter`) is a
typedef whose return type has a constructor with injectable extra parameters.
You can therefore inject `ViewModelFactory<MyViewModel>` into a widget without
writing a `@provides` method for it.

## Asynchronous providers: `@asynchronous`

When a binding needs to be awaited (loading a config, opening a
database), annotate the `Future`-returning provider with
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

`@asynchronous` tells the generator to unwrap the `Future` and register
the binding as `T` instead of `Future<T>`. Consumers see a plain
`Database`. Async-ness surfaces at the entry points instead: an entry
point whose dependency chain contains an `@asynchronous` binding is
declared `Future<T>` and awaited there. `create()` itself is always
synchronous.

To inject the `Future` itself, leave the annotation off. The binding is
then a raw `Future<Database>`.

## Encapsulating subgraphs: `@subcomponent`

Sometimes a group of bindings belongs together but must stay hidden
from the rest of the graph. Examples are an HTTP stack whose client must
be reachable only through a public service, and a session graph with a
shorter lifetime than the app. A subcomponent is an encapsulated child
graph: it can access every parent binding, and its own bindings stay
private. It is also how inject.dart does scoping: each subcomponent
instance is a child scope with its own singletons, runtime values and
private bindings.

Declare the child graph with `@subcomponent` and install it through a
module. Listing that module is the only integration step:

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

Installing `HttpSubcomponent` synthesises an `HttpSubcomponentFactory`
and binds it as an ordinary parent binding. The factory lives in the
`.factory.dart` part file of the library that declares the subcomponent,
which is why the example has a `part` directive. Inject it into a module
provider or a class, or expose it as an entry point, and call
`create(...)` to get a fresh subcomponent instance:

```dart
final component = AppComponent.create();
final httpGraph = component.httpFactory.create();
print(httpGraph.apiService); // but HttpClient stays private to the subgraph
```

How the two graphs relate:

| Aspect | Behaviour |
|---|---|
| Visibility | The child sees every parent binding; the parent sees none of the child's. A parent injection of a child-private type fails with a missing-binding error that names the subcomponent. |
| Scope | `@singleton` inside the subcomponent means once per subcomponent instance. Parent singletons stay app-wide and are shared by all child instances. |
| Re-binding | A subcomponent must not re-declare a binding key that the parent already provides. That is a build error, not an override. |
| Async | `@asynchronous` propagates across the boundary: a child entry point whose chain reaches an async parent binding is declared `Future<T>`. `create(...)` itself always stays synchronous, exactly like components. |
| Runtime values | Give the child module a constructor parameter and pass the instance to `create(httpModule: ...)`, or use `@subcomponentFactory` (see below). |
| Provision listeners | Component-local: a parent listener never observes child provisions, and vice versa (see "Observing provisions" below). |

Each `create(...)` call produces an independent instance, so subcomponents
fit session graphs best. Create the child graph after login and drop the
reference on logout, and all its singletons go with it.
[`examples/bookshelf`][bookshelf-readme] is a complete, runnable app built
around this shape: a login flow creates a `SessionComponent` that holds
session-private credentials and a repository, and logging out releases it.
The FAQ entry "Can I have more than one component?" below covers the other
ways to split an app into several graphs and when a plain second component
fits better.

In Flutter, `inject_flutter`'s `SubcomponentBuilder<T>` widget owns that
lifecycle. It calls `create` once when mounted (sync or `async`), hands the
instance to `builder`, and calls an optional `dispose` when removed from
the tree. Only a widget `Key` change forces a new instance. Place it below
whatever branch point decides that a subcomponent should exist (a
login/logout switch, say), so mounting it is "create" and unmounting it is
"dispose":

```dart
SubcomponentBuilder<SessionComponent>(
  key: ValueKey(credentials), // a new key forces a fresh session
  create: () => sessionFactory.create(credentials),
  builder: (context, session, _) => HomePage(session: session),
)
```

`examples/bookshelf`'s `AuthGate` works this way: it shows the login form
while signed out and mounts `SubcomponentBuilder<SessionComponent>` once
signed in.

To re-export a single binding to the parent, add a parent module
provider that consumes the subcomponent factory. The same binding key
must not exist on both sides of the boundary (see "Re-binding" above),
and the re-export is a parent-provided key. The child therefore binds
the type under a different key, here the `@internal` qualifier from the
example above (a different type works too), and the parent re-export
binds the plain, unqualified `RestApiService`:

```dart
@Module(subcomponents: [HttpSubcomponent])
class NetworkModule {
  @provides
  @singleton
  RestApiService provideApi(HttpSubcomponentFactory factory) =>
      factory.create().apiService;
}
```

### Runtime values: `@subcomponentFactory`

The synthesised `<Name>Factory` above only takes the subcomponent's own
modules as parameters. To pass a runtime value such as a login token or a
request ID straight in, without wrapping it in a module constructor, declare
an explicit factory instead:

```dart
@subcomponentFactory
abstract class HttpSubcomponentFactory {
  HttpSubcomponent create(String userId);
}
```

An `@subcomponentFactory` class must be `abstract` and declare exactly one
abstract method returning the installed `@subcomponent` type. It replaces
the synthesised factory for that subcomponent. Each parameter is classified
independently:

- A parameter whose type is one of the subcomponent's own declared modules
  behaves exactly like a synthesised factory's module parameter.
- Every other parameter is a value parameter. It becomes an instance binding
  in the child graph, injectable by any child binding under its
  `(type, qualifier)` key. `@Qualifier` and nullable-wrap resolution work as
  for any other binding. This is the equivalent of Dagger's `@BindsInstance`
  and Metro's `@Provides` factory parameters.

A factory method may mix both kinds:

```dart
@subcomponentFactory
abstract class HttpSubcomponentFactory {
  HttpSubcomponent create(HttpModule module, String userId);
}
```

`create(...)` stays synchronous, exactly like the synthesised factory.

`@assistedInject` (below) is related: it passes runtime parameters into
the construction of one object through a factory. An
`@subcomponentFactory` value parameter turns a runtime value into a
binding that the entire child graph can inject.

> **Not supported yet:** multi-level hierarchies, where a subcomponent
> installs further subcomponents of its own. Attempting it fails the
> build with "multi-level subcomponent hierarchies are not supported".
> Set and Map multibindings are a separate gap: inject.dart does not
> support them anywhere in the graph yet.

## Runtime parameters: `@assistedInject`

Some constructor parameters are only known at the call site (a widget
key, a screen title, an item id). Mark them `@assisted` and inject the
rest from the graph:

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

Inject the factory wherever you build the page. The caller supplies
`itemId`, and the graph supplies `repository`.

Assisted injection covers a runtime value that one object needs at
construction time. To make a runtime value a binding that a whole
child graph can inject, use "Runtime values: `@subcomponentFactory`"
above instead.

> Declare an `@assistedFactory` abstract class yourself if you need
> multiple `create` variants, a different method name, or a specific
> class name. The synthesised variant is the default for the common
> case.

## Observing provisions: `@provisionListener`

`ProvisionListener<T>` is a callback that fires each time the component
creates an instance of `T`. Use it for centralised logging, metrics, or
for tracking `Closeable`-like resources so a test teardown can release
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

`@provides` exposes the listener as a binding, `@singleton` makes the
same instance observe every provisioned object, and `@provisionListener`
registers it as a hook.

The generic parameter narrows the scope:
`ProvisionListener<ChangeNotifier>` fires only for `ChangeNotifier`
subtypes, and `ProvisionListener<Object>` (or just `ProvisionListener`)
is a catch-all.

A listener must not retain references to instances whose lifecycle is
managed elsewhere (for example ViewModels owned by `ViewModelFactory`),
or the same object could be disposed twice. The implementation above
only observes, so it is safe.

Listeners are component-local and do not cross the parent/child
boundary of a `@subcomponent`. A listener registered in the parent
observes only provisions made by the parent graph, even though the
subcomponent can access the parent's bindings. A listener registered in
a subcomponent's own module observes only that subcomponent's
provisions. There is currently no way for a parent listener to observe
child provisions, or the other way around.

# Flutter integration: `ViewModelFactory`

`inject_flutter` adds one typedef and one widget for ViewModels, plus
`SubcomponentBuilder` (see "Encapsulating subgraphs" above) for owning a
`@subcomponent` graph's lifecycle from a widget:

- `ViewModelFactory<T extends ChangeNotifier>`: a function that
  returns a `ViewModelBuilder<T>`. Inject it into your widget.
- `ViewModelBuilder<T>`: a `StatefulWidget` that:
    1. Calls `viewModelProvider.get()` in `initState` to obtain a fresh
       ViewModel.
    2. Runs the optional `init` callback once. It awaits an asynchronous
       callback (via a `FutureBuilder`), showing the optional `loading`
       widget while it runs and the optional `error` builder if it fails.
    3. Rebuilds via `ListenableBuilder` whenever the ViewModel calls
       `notifyListeners()`.
    4. Calls `viewModel.dispose()` in `State.dispose`.

Use it in one of two ways:

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
depend on the ViewModel. `ListenableBuilder` passes it through without
rebuilding.

# How it works

`build_runner` runs two inject.dart builders, in sequence, over
your sources. The pipeline is declared in
[`packages/inject_generator/build.yaml`][build-yaml]:

1. `factory_builder` runs first. For every `.dart` file that declares
   `@assistedInject` constructors (or an explicit `@assistedFactory`
   abstract class), it emits `<name>.factory.dart`, a `part` file
   containing the factory contracts that the component later implements.
   A file that declares a `@subcomponent` without an explicit
   `@subcomponentFactory` gets the same output: the synthesised
   `<Name>Factory` contract lands there. Files with none of these get
   no output.

2. `inject_builder` runs second. It picks each `@Component` as a
   starting point and walks the dependency graph from there, pulling
   in `@inject`-annotated classes, `@module` providers, and the
   factory contracts emitted in step 1. For each component it
   produces `<name>.inject.dart`, a library containing the concrete
   component class and every supporting `Provider`. Files without a
   `@Component` get no output.

A source file may end up with zero, one, or both of these siblings,
depending on what it contains:

| Source file declares…                          | Produces                                |
|------------------------------------------------|-----------------------------------------|
| only `@inject` classes / modules               | nothing: picked up via the component    |
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
graph. Nothing else is allocated until you call a getter.

[build-yaml]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_generator/build.yaml

# FAQ

### What does "compile-time" mean here?

The generator analyses the dependency graph and writes the wiring code
as part of your build. Nothing is configured or registered at runtime,
and there is no `Type → Instance` map. The output is plain Dart that
behaves like hand-written code.

### Can I have more than one component?

Yes. Components are independent values. Which mechanism to reach for
depends on the relationship between the two graphs:

- For an encapsulated child graph with its own scope, install a
  `@subcomponent` through a module (see "Encapsulating subgraphs"
  above). The child can access every parent binding, its own bindings
  stay private, and its `@singleton`s are scoped to that subcomponent
  instance. This fits a session or per-screen scope that you create and
  drop as one unit.
- For independent graphs with a handful of shared objects, use the
  instance-passing bridge. The feature component lists a module whose
  constructor carries the objects it borrows, and you pass a configured
  instance to the feature component's `create` method:

  ```dart
  final root = RootComponent.create();
  final feature = FeatureComponent.create(
    featureModule: FeatureModule(root.db),
  );
  ```

- For independent graphs with many or async objects, or with no parent
  relationship at all, use the interface bridge. The feature defines a
  narrow interface for what it needs, the other component `implements`
  it, and a bridge module consumes only that interface. This is the
  inject.dart equivalent of Dagger's `@Component(dependencies: [...])`.

`@singleton` is scoped per component instance, so a second component
that lists the same modules builds its own singletons. Both bridge
variants avoid that by getting objects from the other component
instance instead of re-listing its modules. A package split into several
internal modules can also bundle them behind one public module with
`@Module(includes: [...])`, so the app lists only that one module (see
"Umbrella modules" above).
[Scoping, Composing Components and Multi-Package Projects][book-composing]
explains which mechanism to use when.

## Module override semantics

When two or more modules provide the same `(type, qualifier)` pair, the
later module wins. [Dagger 2](https://dagger.dev/) and Hilt behave
differently here: they report two bindings for the same key as a build
error.

```
@Component([ModuleA, ModuleB])   // ModuleB overrides ModuleA for shared keys
```

### Swapping in a test fake

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

### Swapping environments

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

### Overriding a third-party binding

To override a binding from an imported package's module without touching the
package, add your module last. It wins.

An override applies only when both the type and the qualifier are identical.
`@prod String` and `@test String` are different keys and never override each
other, so both providers coexist in the component.

## Builder options

Configure the generator in `build.yaml` under the `inject_generator|inject_builder` key:

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
binding exist for the same type and qualifier in the dependency graph.

| Value               | Behaviour                                                                                                                                    |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `error` *(default)* | Hard build error. The second binding is discarded to minimise downstream noise. Having both variants is almost always a programming mistake. |
| `warn`              | Both bindings are kept and both providers are generated. A `WARNING` diagnostic is emitted on the second binding.                            |
| `allow`             | Both bindings are kept silently, identical to the behaviour before this policy was introduced. Use for gradual migration.                    |

The policy applies only when the qualifier is also identical. `@prod Foo` and
`Foo?` (unqualified) are different keys and are never flagged.

### `debug_graph`

Prints a formatted dependency-graph tree to the build log for each validated
component. Off by default. Enable it temporarily to understand a complex graph
without reading the generated `.inject.dart` line by line.

```yaml
targets:
  $default:
    builders:
      inject_generator|inject_builder:
        options:
          debug_graph: true
```

The output is printed per component directly to stdout and is visible in every
normal build, without a `--verbose` flag:

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

The markers in the output mean:

- `@singleton`: the binding is declared `@singleton`.
- `@async`: the binding is directly or transitively asynchronous (short for `@asynchronous`).
- `@<qualifier>`: the binding carries a qualifier (for example `@brand` for `const brand = Qualifier(#brand)`).
- `<TypeName>...`: shared node (≥ 2 receivers); full details in the shared-bindings block below the tree.
- `injected by: A, B`: every node that depends on this shared binding (in the shared block).
- `… (depth limit reached)`: the dependency chain exceeded 20 levels (the cycle validator would normally catch this first).

A node injected by two or more other nodes appears in the main tree as
`TypeName...` (no annotations, no sub-tree). Its full annotation set, receiver
list, and own dependencies are shown once in the `(shared bindings …)` block
that follows the main tree.

The tree is printed to the build console only and is not written to any
generated file. With `debug_graph: false` or no setting, there is no performance
impact, because the `GraphPrinter` is never instantiated.

### How do I test a class that uses inject.dart?

Usually you construct the class directly with whatever fakes you want.
Every constructor parameter is explicit, so no DI framework is involved
at the unit-test level. To test a whole component, use the module
override pattern described above: build an alternate `@module` that
provides fakes and list it last in
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

Contributions are welcome. Feel free to open a PR.

[example-main]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/example/lib/main.dart
[bookshelf-readme]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/bookshelf/README.md
[rules-file]: https://github.com/ralph-bergmann/inject.dart/blob/master/rules/rules.md
[agentskills]: https://agentskills.io/specification
[dart-package-skills]: https://dart.dev/ai/package-skills
[skills-dir]: https://github.com/ralph-bergmann/inject.dart/tree/master/packages/inject_annotation/skills
[skill-setup]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-setup-di/SKILL.md
[skill-injectable]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-add-injectable/SKILL.md
[skill-module]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-create-module/SKILL.md
[skill-assisted]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-add-assisted-injection/SKILL.md
[skill-provider]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-inject-provider/SKILL.md
[skill-listener]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-add-provision-listener/SKILL.md
[skill-viewmodel]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-flutter-view-model/SKILL.md
[skill-tests]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-write-tests/SKILL.md
