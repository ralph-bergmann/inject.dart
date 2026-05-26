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
not `Future<Database>`. The component's `create` method becomes
asynchronous in turn.

If you actually want to inject the `Future` itself, leave the
annotation off — `Future<Database>` is then just another type.

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

# Flutter integration — `ViewModelFactory`

`inject_flutter` adds one typedef and one widget:

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
   contracts that the component will later implement. Files with no
   assisted injection get no output.

2. **`inject_builder`** runs second. It picks each `@Component` as a
   starting point and walks the dependency graph from there — pulling
   in `@inject`-annotated classes, `@module` providers, and the
   factory contracts emitted in step 1. For each component it
   produces `<name>.inject.dart`, a library containing the concrete
   component class and every supporting `Provider`. Files without a
   `@Component` get no output.

So a given source file may end up with **zero, one, or both** of these
siblings, depending on what it contains:

| Source file declares…             | Produces                                |
|-----------------------------------|-----------------------------------------|
| only `@inject` classes / modules  | nothing — picked up via the component   |
| `@assistedInject` constructor     | `<name>.factory.dart`                   |
| `@Component`                      | `<name>.inject.dart`                    |
| both of the above                 | both siblings                           |

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

Yes. Components are independent values. A common pattern is one root
component for the app and a per-screen or per-feature component that
gets its dependencies from the root.

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
an alternate `@module` that provides fakes, list it last in
`@Component([..., TestModule])`, and pass it to the component's
`create` method.

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
