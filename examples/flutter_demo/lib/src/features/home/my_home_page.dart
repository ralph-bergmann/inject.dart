import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'my_home_page_view_model.dart';

/// Factory to create the [MyHomePage] widget with the [MyHomePageViewModel] injected.
@assistedFactory
abstract class MyHomePageFactory {
  MyHomePage create({Key? key, required String title});
}

/// The home page of the application with a simple counter.
/// The [MyHomePageViewModel] is injected into the widget at compile-time, while the
/// [key] or [title] can be provided at runtime.
class MyHomePage extends StatefulWidget {
  @assistedInject
  const MyHomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelProvider,
  });

  final String title;
  final Provider<MyHomePageViewModel> viewModelProvider;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final MyHomePageViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModelProvider.get();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                return Text(
                  '${viewModel.count}',
                  style: Theme.of(context).textTheme.headlineMedium,
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _incrementCounter() => viewModel.increaseCount();
}
