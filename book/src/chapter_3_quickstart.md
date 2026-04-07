# Quickstart

This chapter builds a counter app the way [`flutter_demo`][flutter-demo] does —
a small, layered Flutter app that follows [Flutter's recommended
architecture][flutter-arch]. Every snippet is taken from that example; open the
linked files alongside this chapter for the complete, running source.

By the end you will know how to:

- add inject.dart to a Flutter project
- annotate classes and provide third-party types with a module
- expose runtime-parameterised widgets with `@assistedInject`
- declare a component and run the generator
- use the wired-up component in `main()`

## Create the project

```bash
flutter create counter_app
cd counter_app
flutter pub add inject_annotation inject_flutter dev:inject_generator dev:build_runner
```

(Chapter 2 covers the packages and their roles in detail.)

## The concepts

inject.dart wires dependencies through a handful of annotations:

| Concept     | Annotation            | What it means                                            |
|-------------|-----------------------|----------------------------------------------------------|
| Injectable  | `@inject`             | The generator constructs this class via its constructor  |
| Module      | `@module`/`@provides` | Provides types you don't own (third-party, interfaces)   |
| Singleton   | `@singleton`          | One shared instance for the component's lifetime         |
| Assisted    | `@assistedInject`     | Mixes graph-injected and runtime parameters              |
| Component   | `@Component`          | Root of the graph; exposes entry points                  |

Everything starts from a `@Component`. The generator traces the graph from its
entry points and resolves every dependency transitively — at build time.

## The files

The app is split by layer, mirroring `flutter_demo`:

```
lib/
├── main.dart                                           @Component root (MainComponent)
└── src/
    ├── app_module.dart                                 AppModule (initial count, …)
    ├── domain/
    │   ├── models/counter.dart                         Counter (immutable domain model)
    │   └── use_cases/increment_counter_use_case.dart   IncrementCounterUseCase
    ├── data/
    │   ├── services/database.dart                      Database + DatabaseModule
    │   └── repositories/counter_repository.dart        CounterRepository
    └── features/
        ├── app/my_app.dart                             MyApp (@assistedInject)
        └── home/
            ├── home_page.dart                          HomePage (@assistedInject)
            └── counter_view_model.dart                 CounterViewModel
```

## Step 1 — Provide a third-party type with a module

`Database` stands in for a third-party library (Drift, Hive, Isar, …). It can't
carry `@inject`, so a `@module` binds it. The module also shows the two-line
`@Qualifier` form to distinguish two `String` config values of the same Dart
type ([more in Core Concepts](./chapter_4_core_concepts.md#named-bindings----qualifier)):

```dart
// lib/src/data/services/database.dart
import 'package:inject_annotation/inject_annotation.dart';

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

class Database {
  Database({required this.path, required this.name});

  final String path;
  final String name;
  int _count = 0;

  Future<void> updateCount(int count) async => _count = count;
  Future<int> selectCount() => Future.value(_count);
}
```

`@provides` tells the generator how to build a `Database`; `@singleton` shares
one instance across the graph. Full source: [`database.dart`][db].

## Step 2 — Annotate your own classes with `@inject`

`Counter` is a plain immutable domain model — no annotation needed:

```dart
// lib/src/domain/models/counter.dart
class Counter {
  const Counter({this.value = 0});

  final int value;

  Counter copyWith({int? value}) => Counter(value: value ?? this.value);
}
```

The repository wraps the service and returns domain models; the use case
encapsulates one operation. Both are stateless, so both are `@singleton`:

```dart
// lib/src/data/repositories/counter_repository.dart
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

```dart
// lib/src/domain/use_cases/increment_counter_use_case.dart
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

`@inject` tells the generator to construct the class via its constructor,
resolving each parameter from the graph. Full source:
[`counter_repository.dart`][repo], [`increment_counter_use_case.dart`][usecase].

## Step 3 — The ViewModel

The ViewModel holds the mutable UI state and extends `ChangeNotifier`. It is
**not** a singleton — each screen gets its own:

```dart
// lib/src/features/home/counter_view_model.dart
@inject
class CounterViewModel extends ChangeNotifier {
  CounterViewModel({
    required this._incrementUseCase,
    required this._initialCount,
  });

  final IncrementCounterUseCase _incrementUseCase;
  final Future<int> _initialCount;

  Counter _counter = const Counter();
  Counter get counter => _counter;

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

`_initialCount` is a raw `Future<int>` binding (no `@asynchronous`) — the
ViewModel awaits it itself in `init()`. This keeps the ViewModel's dependency
chain synchronous, which `ViewModelFactory` requires ([the two async patterns
are explained in Core Concepts](./chapter_4_core_concepts.md#asynchronous-providers----asynchronous)).
Full source: [`counter_view_model.dart`][vm].

## Step 4 — Widgets with `@assistedInject`

A widget needs DI-managed dependencies (a `ViewModelFactory`) *and* runtime
parameters (`key`, `title`). `@assistedInject` mixes the two. **Each file that
declares an `@assistedInject` constructor needs its own
`part '<file>.factory.dart';` directive** so the factory builder can write the
generated factory next to it:

```dart
// lib/src/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import 'counter_view_model.dart';

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

- `@assisted` parameters (`key`, `title`) come from the caller at runtime.
- Parameters without `@assisted` (`viewModelFactory`) come from the graph.
- The generator synthesises a `HomePageFactory` into `home_page.factory.dart` —
  you never write it.
- `ViewModelFactory<CounterViewModel>` (from `inject_flutter`) creates the VM in
  `initState`, runs the `init:` callback you pass once (awaiting it when async
  and showing `loading:` meanwhile), rebuilds the subtree on `notifyListeners()`,
  and disposes the VM in `dispose`. Passing `init: (vm) => vm.init()` is what
  runs `init()` — the factory does not call it automatically.

The root `MyApp` widget follows the same pattern — its own file, its own `part`
directive, injecting the synthesised `HomePageFactory`:

```dart
// lib/src/features/app/my_app.dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../home/home_page.dart';

part 'my_app.factory.dart';

class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({@assisted super.key, required this.homePageFactory});

  final HomePageFactory homePageFactory;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: homePageFactory.create(title: 'Flutter Counter Demo'),
      );
}
```

Full source: [`home_page.dart`][home], [`my_app.dart`][myapp].

## Step 5 — A module for the initial count

`CounterViewModel` needs a `Future<int>` for its initial value. A small
`AppModule` provides it:

```dart
// lib/src/app_module.dart
@module
class AppModule {
  @provides
  @singleton
  Future<int> provideInitialCount() => Future.value(0);
}
```

> In `flutter_demo`, `AppModule` also wires app metadata (an `@asynchronous`
> `AppInfo`), a `@welcome` message, and a `@provisionListener` — see
> [`app_module.dart`][appmod] and [Core Concepts](./chapter_4_core_concepts.md).

## Step 6 — Declare the component

The component is the graph root. It lists its modules and exposes entry points.
`main.dart` holds **only** the `@Component` — it has no `@assistedInject`
constructor, so it takes **no** `part` directive; it imports the generated
component library instead:

```dart
// lib/main.dart
import 'main.inject.dart' as g;

@Component([AppModule, DatabaseModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;
  // flutter_demo also exposes welcomeMessage, counterRepositoryProvider,
  // and creationLogListener — see main.dart.
}
```

- `import 'main.inject.dart' as g;` — the generated component class lives here;
  the `as g` prefix keeps generated names out of your namespace.
- Module order matters: a later module overrides an earlier one for the same
  `(type, qualifier)` key.

## Step 7 — Run the generator

```bash
dart run build_runner build
```

The generator writes, next to each source file:

- `lib/main.inject.dart` — the component implementation (next to `main.dart`).
- `lib/src/features/home/home_page.factory.dart` — `HomePageFactory`.
- `lib/src/features/app/my_app.factory.dart` — `MyAppFactory`.

A `.factory.dart` is emitted **only** for files that declare `@assistedInject`
(or `@assistedFactory`). `main.dart` has neither, so there is no
`main.factory.dart`.

## Step 8 — Use the component in `main()`

```dart
void main() {
  final component = MainComponent.create();
  runApp(component.myAppFactory.create());
}
```

`MainComponent.create()` returns the wired component; `myAppFactory.create()`
produces a `MyApp` with every injected dependency already in place.

## Troubleshooting

### "component class must declare at least one @inject-annotated provider"

A `@Component` must expose at least one entry point via an `@inject` getter
(here, `myAppFactory`). Add one if your component has none.

### "Could not find a way to provide X"

The generator has no binding for a dependency. Common causes:

- the class is missing `@inject`;
- it's a third-party type with no `@module` + `@provides`;
- the module is not listed in `@Component([...])`;
- a `@Qualifier` on the consumer matches no provider.

### Missing `part '<file>.factory.dart';` directive

A file with an `@assistedInject` (or `@assistedFactory`) constructor needs a
`part '<file>.factory.dart';` directive **in that same file** — for example
`part 'home_page.factory.dart';` in `home_page.dart`. It is *not* added to the
component file unless the component file itself declares an assisted
constructor.

## Complete example

The full, running source is in [`flutter_demo`][flutter-demo]. For a single-file
variant, see [`examples/example/lib/main.dart`][example-main]. The deeper
architecture walkthrough is in
[State Management and Application Architecture](./chapter_5_state_management.md).

[flutter-arch]: https://docs.flutter.dev/app-architecture
[flutter-demo]: https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo
[example-main]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/example/lib/main.dart
[db]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/data/services/database.dart
[repo]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/data/repositories/counter_repository.dart
[usecase]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/domain/use_cases/increment_counter_use_case.dart
[vm]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/features/home/counter_view_model.dart
[home]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/features/home/home_page.dart
[myapp]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/features/app/my_app.dart
[appmod]: https://github.com/ralph-bergmann/inject.dart/blob/master/examples/flutter_demo/lib/src/app_module.dart
