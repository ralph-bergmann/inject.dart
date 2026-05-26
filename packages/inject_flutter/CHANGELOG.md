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
