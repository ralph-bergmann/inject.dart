import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import 'counter_view_model.dart';

part 'home_page.factory.dart';

/// The counter home screen.
///
/// [@assistedInject] lets inject.dart supply [viewModelFactory] from the DI
/// graph at build time while leaving [key] and [title] to the caller at
/// runtime. The generated [HomePageFactory.create(key:, title:)] hides every
/// graph-managed parameter.
class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory,
  });

  final String title;

  /// [ViewModelFactory] bridges inject.dart and Flutter's widget lifecycle.
  ///
  /// Internally it wraps a [Provider<CounterViewModel>] inside a
  /// [ViewModelBuilder]: it creates a fresh [CounterViewModel] in
  /// [State.initState], runs [CounterViewModel.init] once — awaiting it when
  /// asynchronous and showing the `loading` widget meanwhile — wires
  /// [ListenableBuilder] so the subtree rebuilds on [notifyListeners], and
  /// disposes the VM in [State.dispose].
  ///
  /// Keeping the *factory* here (not the VM) is what lets [HomePage] remain
  /// a [StatelessWidget] — the generated [ViewModelBuilder] owns the
  /// stateful parts.
  final ViewModelFactory<CounterViewModel> viewModelFactory;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(
      // [CounterViewModel.init] is asynchronous; [ViewModelBuilder] awaits it
      // and shows [loading] until it completes (here it resolves immediately).
      init: (vm) => vm.init(),
      loading: const Center(child: CircularProgressIndicator()),
      builder: (context, vm, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(title),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have pushed the button this many times:'),
                Text(
                  '${vm.counter.value}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: vm.increment,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
