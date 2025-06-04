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
