# State Management and Application Architecture

This chapter shows how inject.dart fits into a layered Flutter application that
follows [Flutter's recommended app architecture][flutter-arch]. We will walk
through the `flutter_demo` reference example — a counter app structured in
layers — and explain where inject.dart helps and where it deliberately diverges
from the guide.

The complete source lives in [`examples/flutter_demo`][flutter-demo].

## Flutter's recommended architecture

[Flutter's app architecture guide][flutter-arch] defines a layered approach:

| Layer        | Responsibility                                    |
|--------------|---------------------------------------------------|
| Domain Model | Immutable data structures (value objects)         |
| Service      | Wraps external APIs, databases, platform channels |
| Repository   | Caches, transforms; returns Domain Models         |
| Use Case     | Encapsulates a single business operation          |
| ViewModel    | Holds mutable UI state; extends `ChangeNotifier`  |
| View         | Renders UI; subscribes to ViewModel               |

Each layer depends only on the layer below it, never on the layer above.

### Where inject.dart fits: Step 7

The guide's dependency-wiring step (Step 7) recommends wiring dependencies with
a runtime service locator such as `get_it`, or a `provider` tree. inject.dart
takes a different approach: **compile-time constructor injection**.

Instead of registering bindings in an imperative setup block and resolving them
at runtime, you annotate your classes and modules, run the generator, and get a
concrete component class that knows how to build every dependency — verified at
build time.

The trade-off is the same one described in the Introduction: a codegen step in
exchange for build-time safety.

## The `flutter_demo` layers

```
lib/
├── main.dart                              @Component root (MainComponent)
└── src/
    ├── app_module.dart                    AppModule + CreationLogListener
    ├── domain/
    │   ├── models/
    │   │   └── counter.dart               Counter (immutable domain model)
    │   └── use_cases/
    │       └── increment_counter_use_case.dart  IncrementCounterUseCase
    ├── data/
    │   ├── services/
    │   │   └── database.dart              Database + DatabaseModule
    │   └── repositories/
    │       └── counter_repository.dart    CounterRepository
    └── features/
        ├── app/
        │   └── my_app.dart                MyApp (@assistedInject)
        └── home/
            ├── home_page.dart             HomePage (@assistedInject)
            └── counter_view_model.dart    CounterViewModel (@inject)
```

### Domain Model — `Counter`

A plain immutable class with value semantics. No DI annotation is needed:

```dart
class Counter {
  const Counter({this.value = 0});

  final int value;

  Counter copyWith({int? value}) => Counter(value: value ?? this.value);
}
```

Using `freezed` or `built_value` (as Flutter's guide recommends) is an option;
this example uses a hand-written class to keep the inject.dart concepts front
and centre.

### Service — `Database` and `DatabaseModule`

`Database` is a simulated third-party type. It cannot carry `@inject`, so a
module provides it. The module also demonstrates the two-line `@Qualifier` form
to distinguish two `String` config values of the same Dart type:

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
    @databasePath String path,
    @databaseName String name,
  ) => Database(path: path, name: name);
}
```

Both `@databasePath String` and `@databaseName String` have the same Dart type.
inject.dart routes them correctly because binding identity is `(type, qualifier)`.

### Repository — `CounterRepository`

The repository sits between the raw service and the rest of the app. Consumers
always work with `Counter` domain models; they never touch `Database` directly:

```dart
@inject
@singleton
class CounterRepository {
  const CounterRepository({required this._database});

  final Database _database;

  Future<Counter> get counter async =>
      Counter(value: await _database.selectCount());

  Future<void> increment() async {
    final current = await _database.selectCount();
    await _database.updateCount(current + 1);
  }
}
```

`@singleton` means the same `CounterRepository` instance is shared across the
whole component — a single source of truth for the counter state.

### Use Case — `IncrementCounterUseCase`

A use case encapsulates one business operation. This one is **stateless** — it
holds only a reference to its collaborator — so it is marked `@singleton`: a
single shared instance is safe and avoids needless allocations.

```dart
@inject
@singleton
class IncrementCounterUseCase {
  const IncrementCounterUseCase({required this._repository});

  final CounterRepository _repository;

  Future<Counter> execute() async {
    await _repository.increment();
    return _repository.counter;
  }
}
```

Whether a binding should be a singleton depends on whether it carries
per-consumer mutable state, **not** on the lifecycles of its dependencies. A use
case that *did* hold consumer-specific state would drop `@singleton` and receive
a fresh instance per injection instead.

`CounterViewModel` injects `IncrementCounterUseCase`; the repository is wired
automatically by the generator.

### ViewModel — `CounterViewModel`

The ViewModel holds all mutable state and keeps the View as a `StatelessWidget`:

```dart
@inject
class CounterViewModel extends ChangeNotifier {
  CounterViewModel({
    required IncrementCounterUseCase incrementUseCase,
    required Future<int> initialCount,
  }) : _incrementUseCase = incrementUseCase,
       _initialCount = initialCount;

  final IncrementCounterUseCase _incrementUseCase;
  final Future<int> _initialCount;

  Counter _counter = const Counter();
  Counter get counter => _counter;

  // Runs once when the ViewModel is created. HomePage wires this in via
  // init: (vm) => vm.init(); because it is async, ViewModelBuilder awaits it
  // (showing its loading widget meanwhile). The factory does not call it
  // automatically — you must pass init:.
  Future<void> init() async {
    _counter = Counter(value: await _initialCount);
    notifyListeners();
  }

  Future<void> increment() async {
    _counter = await _incrementUseCase.execute();
    notifyListeners();
  }
}
```

Note `Future<int>` — this is a raw future binding **without** `@asynchronous`.
`AppModule.provideInitialCount()` returns `Future.value(0)` synchronously to
*provision*; `CounterViewModel` holds the `Future` and awaits it in `init()`.
This keeps the ViewModel chain synchronous from the generator's perspective,
which is required by `ViewModelFactory`.

Dependencies are kept `private`; the View can only access what the ViewModel
intentionally exposes through its public API.

### View — `HomePage` and `MyApp`

The View uses `@assistedInject` to receive the `ViewModelFactory` from the
graph and runtime parameters from the caller:

```dart
part 'home_page.factory.dart';

class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory,
  });

  final String title;
  final ViewModelFactory<CounterViewModel> viewModelFactory;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(
      init: (vm) => vm.init(),
      loading: const Center(child: CircularProgressIndicator()),
      builder: (context, vm, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text('${vm.counter.value}')),
        floatingActionButton: FloatingActionButton(
          onPressed: vm.increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

`ViewModelFactory<CounterViewModel>` is the `inject_flutter` lifecycle bridge:

1. Creates a fresh `CounterViewModel` in `State.initState`.
2. Runs the `init:` callback you pass once (here `(vm) => vm.init()`); without
   that argument no initialisation runs. An `async` initializer is awaited and
   the `loading:` widget is shown until it completes.
3. Wires `ListenableBuilder` so the subtree rebuilds on `notifyListeners()`.
4. Calls `vm.dispose()` in `State.dispose`.

The `part 'home_page.factory.dart';` directive is required because the factory
builder writes the synthesised `HomePageFactory` into that part file.

### Component root — `MainComponent`

```dart
import 'main.inject.dart' as g;

@Component([AppModule, DatabaseModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;

  @welcome
  @inject
  Future<String> get welcomeMessage;

  @inject
  Provider<CounterRepository> get counterRepositoryProvider;

  @inject
  CreationLogListener get creationLogListener;
}
```

Module order is meaningful: `AppModule` first, `DatabaseModule` second. If both
provided the same `(type, qualifier)` pair, `DatabaseModule` would win.

`Provider<CounterRepository>` as an entry point defers creation to `.get()` —
useful for lazy access or passing the provider to non-DI code.

## `@asynchronous` in the app module

`flutter_demo` showcases both async patterns (see [Core Concepts](./chapter_4_core_concepts.md#asynchronous-providers----asynchronous)):

- `AppModule.provideAppInfo()` — `@asynchronous`, binding type `AppInfo`
- `AppModule.provideWelcomeMessage(AppInfo)` — `@asynchronous`, receives `AppInfo` already resolved
- `AppModule.provideInitialCount()` — **no** `@asynchronous`, binding type `Future<int>`

The welcome-message chain propagates async-ness to the component entry point
(`Future<String> get welcomeMessage`). The initial-count chain stays
synchronous, keeping the ViewModel chain compatible with `ViewModelFactory`.

## `@provisionListener` in `AppModule`

```dart
@provides
@singleton
@provisionListener
CreationLogListener provideCreationLogListener() => CreationLogListener();
```

`CreationLogListener implements ProvisionListener<ChangeNotifier>`, so it fires
for every `ChangeNotifier` the component provisions — here, every
`CounterViewModel` instance. It is a `@singleton` so one listener observes all
provisioning events.

## Entry point in `main()`

```dart
void main() async {
  final component = MainComponent.create();
  debugPrint(await component.welcomeMessage);
  runApp(component.myAppFactory.create());
}
```

`MainComponent.create()` returns the component immediately. Bindings are
constructed lazily on first access and singletons are cached thereafter, so a
plain getter is a simple field read or a cached `Provider.get()`.

[flutter-arch]: https://docs.flutter.dev/app-architecture
[flutter-demo]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo
