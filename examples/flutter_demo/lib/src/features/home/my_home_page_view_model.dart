import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../../data/repositories/counter_repository.dart';
import 'my_home_page.dart';

/// The view model for the [MyHomePage] widget.
@inject
class MyHomePageViewModel extends ChangeNotifier {
  MyHomePageViewModel({required CounterRepository repository}) : _repository = repository;

  final CounterRepository _repository;

  int count = 0;

  Future<void> increaseCount() async {
    await _repository.increaseCount();
    count = await _repository.count;
    notifyListeners();
  }
}

class MyHomePageViewModelProvider extends Provider<MyHomePageViewModel> {
  @override
  MyHomePageViewModel get() {
    return MyHomePageViewModel(repository: repository);
  }
}

typedef ViewModelWidgetBuilder<T extends ChangeNotifier> = Widget Function(
  BuildContext context,
  T viewModel,
  Widget? child,
);

final class MyHomePageViewModelBuilder {
  const MyHomePageViewModelBuilder();

  ViewModelBuilder<MyHomePageViewModel> call({
    required ViewModelWidgetBuilder<MyHomePageViewModel> builder,
    Widget? child,
  }) {
    return ViewModelBuilder<MyHomePageViewModel>(
      viewModelProvider: MyHomePageViewModelProvider(),
      builder: builder,
    );
  }
}

final class ViewModelBuilder<T extends ChangeNotifier> extends StatefulWidget {
  const ViewModelBuilder({
    super.key,
    required this.viewModelProvider,
    required this.builder,
    this.child,
  });

  final Provider<T> viewModelProvider;
  final ViewModelWidgetBuilder<T> builder;
  final Widget? child;

  @override
  State<ViewModelBuilder<T>> createState() => _ViewModelBuilderState<T>();
}

final class _ViewModelBuilderState<T extends ChangeNotifier> extends State<ViewModelBuilder<T>> {
  late final T _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModelProvider.get();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _viewModel,
        builder: (context, child) => widget.builder(
          context,
          _viewModel,
          child,
        ),
        child: widget.child,
      );
}
