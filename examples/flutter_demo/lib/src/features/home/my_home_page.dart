import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import 'my_home_page_view_model.dart';

/// Factory to create the [MyHomePage] widget with the [MyHomePageViewModel] injected.
@assistedFactory
abstract class MyHomePageFactory {
  MyHomePage create({Key? key, required String title});
}

/// The home page of the application with a simple counter.
/// The [viewModelFactory] is injected into the widget at compile-time, while the
/// [key] or [title] can be provided at runtime.
class MyHomePage extends StatelessWidget {
  @assistedInject
  const MyHomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory,
  });

  final String title;

  final ViewModelFactory<MyHomePageViewModel> viewModelFactory;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: Text(title),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'You have pushed the button this many times:',
                ),
                Text(
                  '${viewModel.count}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: viewModel.increaseCount,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
