# inject_flutter

Flutter-specific extension for [inject.dart](https://ralph-bergmann.github.io/inject.dart/) 
that simplifies ViewModel injection and lifecycle management to promote cleaner 
architecture in Flutter apps.

## Features

- **Automatic ViewModel Lifecycle Management**: Create and dispose ViewModels
  automatically with widget lifecycle
- **Clean Widget Architecture**: Separate business logic from UI code
- **Reactive UI Updates**: Widgets automatically rebuild when ViewModel state
  changes
- **Seamless Integration**: Works directly with inject.dart's dependency
  injection system
- **Type-safe**: Compile-time checking ensures your dependencies are correctly
  configured

## Installation

To use this library in your Dart or Flutter project, you need to add it as a
dependency in your `pubspec.yaml` file:

```shell
// dart
$ dart pub add inject_flutter inject_annotation dev:inject_generator dev:build_runner

// flutter
$ flutter pub add inject_flutter inject_annotation dev:inject_generator dev:build_runner
```

## Usage

### 1. Create a ViewModel

First, create a ViewModel that extends [`ChangeNotifier`](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html):

```dart
import 'package:flutter/foundation.dart';
import 'package:inject_annotation/inject_annotation.dart';

@inject
class HomePageViewModel extends ChangeNotifier {
  int count = 0;

  void incrementCounter() {
    count++;
    notifyListeners();
  }
}
```

### 2. Create a Widget using ViewModelFactory

Inject the [`ViewModelFactory`](https://pub.dev/documentation/inject_flutter/latest/inject_flutter/ViewModelFactory.html)
into your widget to automatically handle ViewModel lifecycle:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';
import 'home_page_view_model.dart';

@assistedFactory
abstract class HomePageFactory {
  HomePage create({
    Key? key,
    required String title,
  });
}

class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({
    @assisted super.key,
    @assisted required this.title,
    required this.viewModelFactory,
  });

  final String title;
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
                style: Theme
                    .of(context)
                    .textTheme
                    .headlineMedium,
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
```

### 3. Set up your Component

Create a [`component`](https://pub.dev/documentation/inject_annotation/latest/inject/Component-class.html) 
to tie everything together:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'home_page.dart';

import 'main.inject.dart' as g;

void main() {
  final mainComponent = AppComponent.create();
  final app = mainComponent.exampleAppFactory.create();
  runApp(app);
}

@component
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  HomePageFactory get homePageFactory;
}

@assistedFactory
abstract class ExampleAppFactory {
  ExampleApp create({Key? key});
}

class ExampleApp extends StatelessWidget {
  @assistedInject
  const ExampleApp({
    @assisted super.key,
    required this.homePageFactory,
  });

  final HomePageFactory homePageFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: homePageFactory.create(title: 'Flutter Demo Home Page'),
    );
  }
}
```

### 4. Generate the Code

Run the `build_runner` to generate the necessary code:

```shell
dart run build_runner build
```

## How It Works

The `ViewModelFactory` automatically:

1. Creates the ViewModel instance when the widget is initialized
2. Listens for state changes and rebuilds the widget when needed
3. Disposes the ViewModel when the widget is removed from the tree

This gives you a clean separation of business logic from UI code without manual
lifecycle management.

## Complete Example

See the [example folder](https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_flutter/example/lib/main.dart)
for a complete working example of a counter app that demonstrates:

- ViewModel injection and lifecycle management
- Using factories for creating widgets with injected dependencies
- Assisted injection for parameters provided at runtime
- Proper component setup

## Additional Information

- Check the [documentation](https://ralph-bergmann.github.io/inject.dart/) for
  more details about inject.dart
- Issues and feature requests can be filed on
  the [GitHub issue tracker](https://github.com/ralph-bergmann/inject.dart/issues)
- Contributions are welcome! Please feel free to submit a Pull Request
