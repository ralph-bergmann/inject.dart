import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import 'main.inject.dart' as g;

void main() {
  final mainComponent = AppComponent.create();
  final app = mainComponent.exampleAppFactory.create();
  runApp(app);
}

/// The main component of the application.
/// Responsible for creating and managing dependencies of the application.
/// Root of the dependency graph.
@component
abstract class AppComponent {
  /// A factory method to create a new instance of [AppComponent].
  static const create = g.MainComponent$Component.create;

  /// Returns an instance of [ExampleAppFactory] to create the [ExampleApp] widget.
  @inject
  ExampleAppFactory get exampleAppFactory;
}

/// Factory to create the [ExampleApp] widget with the [HomePageFactory] injected.
@assistedFactory
abstract class ExampleAppFactory {
  ExampleApp create({Key? key});
}

/// The App.
class ExampleApp extends StatelessWidget {
  @assistedInject
  const ExampleApp({
    @assisted super.key,
    required this.homePageFactory,
  });

  /// The factory to create the [HomePage] widget.
  final HomePageFactory homePageFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: homePageFactory.create(title: 'Flutter Demo Home Page'),
    );
  }
}

/// The ViewModel.
@inject
class HomePageViewModel extends ChangeNotifier {
  var count = 0;

  void incrementCounter() {
    count++;
    notifyListeners();
  }
}

/// Factory to create the [HomePage] widget with the [MyHomePageFactory] injected.
/// [key] and [title] can be, but don't have to be provided at runtime.
@assistedFactory
abstract class HomePageFactory {
  HomePage create({
    Key? key,
    required String title,
  });
}

/// The HomePage
class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory,
  });

  final String title;

  /// Factory to create the [HomePageViewModel] which also handles the lifecycle of it
  /// and rebuilds the body when the [HomePageViewModel] gets updated.
  final ViewModelFactory<HomePageViewModel> viewModelFactory;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(builder: (context, viewModel, _) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('You have pushed the button this many times:'),
              Text(
                '${viewModel.count}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: viewModel.incrementCounter,
          child: const Icon(Icons.add),
        ),
      );
    });
  }
}
