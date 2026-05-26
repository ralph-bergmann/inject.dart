---
name: inject_annotation-flutter-view-model
description: Binds a ChangeNotifier view model to a Flutter widget with inject.dart's inject_flutter package — inject a ViewModelFactory<T>, call it to get a ViewModelBuilder that owns the view model lifecycle, and run a synchronous or asynchronous init with loading/error widgets. Use when the user says "create a view model", "inject a ViewModel", "ViewModelFactory/ViewModelBuilder", "MVVM with inject.dart", "ChangeNotifier in Flutter DI", or needs widget-scoped state with async initialization.
license: BSD-3-Clause
metadata:
  author: ralph-bergmann
  package: inject.dart
  last_modified: "2026-05-25"
---

# Inject a Flutter view model

`inject_flutter` bridges inject.dart and Flutter for `ChangeNotifier`-based view
models that are **owned by a single widget**. You inject a `ViewModelFactory<T>`
and call it; the returned `ViewModelBuilder` creates the view model in
`initState`, rebuilds on `notifyListeners`, and disposes it in `dispose` — so
the host widget can stay a `StatelessWidget`.

## Setup

```bash
flutter pub add inject_flutter
```

(`inject_annotation`, `inject_generator` and `build_runner` must already be set
up — see `inject_annotation-setup-di`.)

## Task progress

- [ ] 1. Write the `ChangeNotifier` view model with an `@inject` constructor
- [ ] 2. Expose a `ViewModelFactory<T>` from the component
- [ ] 3. Call the factory in the widget
- [ ] 4. Add sync or async `init` (with `loading`/`error`)
- [ ] 5. Regenerate and verify

## Steps

### 1. Write the view model

```dart
@inject
class CounterViewModel extends ChangeNotifier {
  CounterViewModel(this._repository);

  final CounterRepository _repository;
  int count = 0;

  // Optional initializer — may be sync or async.
  Future<void> init() async {
    count = await _repository.current();
    notifyListeners();
  }

  Future<void> increment() async {
    count = await _repository.increment();
    notifyListeners();
  }
}
```

- Extend `ChangeNotifier` and call `notifyListeners()` on state changes.
- Annotate the view model with `@inject` (or its constructor); its dependencies
  come from the graph.
- **Never** mark a view model `@singleton` — the generator rejects it
  (`ViewModelFactory<T> cannot use a @singleton ViewModel`); each widget owns
  its own instance.
- The view model's **construction (provider-resolution) chain** must be
  synchronous — an `@asynchronous` binding anywhere in it is a build error
  (`ViewModelFactory<T> cannot use an asynchronous ViewModel`). Holding a raw
  `Future<T>` field (from a provider with **no** `@asynchronous`) is fine; await
  it in `init`. Do asynchronous work in `init`, never in the constructor.

### 2. Expose a `ViewModelFactory<T>` from the component

```dart
@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  ViewModelFactory<CounterViewModel> get counterViewModelFactory;
}
```

### 3. Call the factory in the widget

Inject the **factory**, then **call it** — it returns a `ViewModelBuilder`.
Never construct `ViewModelBuilder` by hand and never inject the view model
directly. The `builder` receives `(context, viewModel, child)`.

```dart
class CounterPage extends StatelessWidget {
  const CounterPage({super.key, required this.factory});

  final ViewModelFactory<CounterViewModel> factory;

  @override
  Widget build(BuildContext context) {
    return factory(
      builder: (context, vm, child) => Scaffold(
        body: Center(child: Text('Count: ${vm.count}')),
        floatingActionButton: FloatingActionButton(
          onPressed: vm.increment,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

(To pass the factory into the widget through the graph alongside runtime
parameters like a title or `Key`, combine this with
`inject_annotation-add-assisted-injection`.)

### 4. Add `init` (synchronous or asynchronous)

`init` runs **once** when the view model is created. Its signature is
`FutureOr<void> Function(T)`:

- A **synchronous** (or absent) `init` builds the UI immediately.
- An **asynchronous** `init` is awaited via a `FutureBuilder`: `loading` shows
  while it runs, and `error` (a `ViewModelErrorBuilder`,
  `(context, error, stackTrace)`) shows if it throws. With **no** `error`
  builder, a failed init is reported via `FlutterError.reportError` rather than
  silently dropped.

```dart
return factory(
  init: (vm) => vm.init(), // async: awaited before builder runs
  loading: const Center(child: CircularProgressIndicator()),
  error: (context, error, stackTrace) => Center(child: Text('Failed: $error')),
  builder: (context, vm, child) => Text('Count: ${vm.count}'),
);
```

### 5. Regenerate and verify

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

## ViewModelFactory call surface

`factory({Key? key, ViewModelInitializer<T>? init, Widget? loading, ViewModelErrorBuilder? error, required ViewModelWidgetBuilder<T> builder, Widget? child})`

- `init` — `FutureOr<void> Function(T)`, runs once.
- `loading` — shown only while an async `init` runs (default: empty box).
- `error` — `Widget Function(context, Object error, StackTrace?)`, async-init
  failures only.
- `builder` — `Widget Function(context, T viewModel, Widget? child)`, rebuilt on
  `notifyListeners`.
- `child` — optional non-rebuilding subtree passed to `builder`.

## Common mistakes

- **Constructing `ViewModelBuilder` directly** or injecting the view model
  instead of the factory → inject `ViewModelFactory<T>` and call it.
- **A two-argument `builder`** → the callback takes `(context, vm, child)`.
- **`@singleton` on the view model** → forbidden; widgets own their instances.
- **Async work in the constructor** → the construction chain must be sync;
  move it to `init`.
- **An async `init` with no `loading`/`error`** → UI shows an empty box while
  loading and errors go to `FlutterError.reportError`; supply both for real UX.
