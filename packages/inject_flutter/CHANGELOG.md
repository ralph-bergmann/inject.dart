## 1.2.1

- add missing example

## 1.2.0

* Added `SubcomponentBuilder<T>`: a `StatefulWidget` that owns the lifecycle of a `@subcomponent` graph (e.g. a login session). It calls its `create` callback (sync or `async`) exactly once in `initState`, exposes the result through `builder(context, subcomponent, child)`, and calls the optional `dispose` callback with the instance when removed from the tree. An asynchronous `create` shows the optional `loading` widget while it runs and the optional `error` builder (or, if none is given, `FlutterError.reportError`) if it fails. A widget `Key` change is the only recreation trigger — same convention as `ViewModelBuilder`. Unlike `ViewModelBuilder`, the created value is not expected to be a `ChangeNotifier`; `SubcomponentBuilder` never listens to it.

```dart
SubcomponentBuilder<SessionComponent>(
  key: ValueKey(credentials),
  create: () => sessionFactory.create(credentials),
  builder: (context, session, _) => HomePage(session: session),
);
```

## 1.1.1

* fix dependency conflict with flutter_test

## 1.1.0

* `ViewModelInitializer` now accepts an **asynchronous** `init` callback (its type widened from `void Function(T)` to `FutureOr<void> Function(T)`). An asynchronous `init` is awaited via a `FutureBuilder`, so a long-running `init` no longer races the first frame. Synchronous `init` callbacks keep working unchanged.
* Added optional `loading` and `error` widgets to `ViewModelFactory` / `ViewModelBuilder`: `loading` is shown while an asynchronous `init` runs and `error` (a `ViewModelErrorBuilder`) when it fails. Without an `error` builder, an init failure is reported through `FlutterError.reportError` instead of being silently dropped. Both are ignored for a synchronous `init`.

```dart
viewModelFactory(
  init: (viewModel) => viewModel.load(), // may be sync or async
  loading: const Center(child: CircularProgressIndicator()),
  error: (context, error, _) => Center(child: Text('$error')),
  builder: (context, viewModel, _) => /* widget */,
);
```

## 1.0.2

* Added support for ViewModel initialization via an optional `init` callback in `ViewModelFactory`

```dart
@override
Widget build(BuildContext context) {
  return viewModelFactory(
    // Initialize the ViewModel when it's created
    init: (viewModel) {
      // Perfect place to trigger data loading
      viewModel.loadData();
    },
    builder: (context, viewModel, _) {
      return Scaffold(
        appBar: AppBar(title: Text(viewModel.title)),
        body: viewModel.isLoading 
          ? const CircularProgressIndicator()
          : ListView.builder(
              itemCount: viewModel.items.length,
              itemBuilder: (context, index) => 
                ItemTile(item: viewModel.items[index]),
            ),
      );
    },
  );
}
```

## 1.0.1

* inject_annotation version 1.0.0 and inject_generator version 1.0.0
* update README

## 1.0.0

* initial release
