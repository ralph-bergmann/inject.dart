# inject.dart - Compile-time Dependency Injection for Dart and Flutter

inject.dart is a compile-time dependency injection framework for Dart with
excellent Flutter integration. It provides a clean, type-safe way to manage
dependencies with minimal boilerplate code, excellent performance, and seamless
integration with Flutter's widget lifecycle.

## Packages

This repository contains the following packages:

- **inject_annotation**: Core annotations for dependency injection
- **inject_generator**: Code generator that processes the annotations
- **inject_flutter**: Flutter-specific extensions that simplify ViewModel
  injection and lifecycle management

## Features

- **Type-safe Dependency Injection**: Compile-time checking ensures your
  dependencies are correctly configured
- **No Reflection**: Zero runtime overhead for dependency resolution
- **Singleton Support**: Easy creation of singleton instances
- **Modular Design**: Use modules to organize your dependencies

## For Flutter Apps

- **Automatic View Model Lifecycle Management**: Create and dispose view models
  automatically with widget lifecycle
- **Clean Widget Architecture**: Separate business logic from UI code
- **Reactive UI Updates**: Widgets automatically rebuild when view model state
  changes

# Installation

## For Flutter Projects

```shell
flutter pub add inject_flutter inject_annotation dev:inject_generator dev:build_runner
```

## For Dart Projects

```shell
dart pub add inject_annotation dev:inject_generator dev:build_runner
```

# Usage (Flutter)

## 1. Create a View Model

First, create a view model that extends `ChangeNotifier`:

```dart
@inject
class HomePageViewModel extends ChangeNotifier {
  int count = 0;

  void incrementCounter() {
    count++;
    notifyListeners();
  }
}
```

## 2. Create a Widget using ViewModelFactory

Inject the `ViewModelFactory` into your widget to automatically handle view
model lifecycle:

```dart
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
```

## 3. Set up your Component

Create a component to tie everything together:

```dart
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
  ExampleAppFactory get exampleAppFactory;
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

## 4. Generate the Code

Run the `build_runner` to generate the necessary code:

```shell
dart run build_runner build
```

# Core Dependency Injection

Whether using Flutter or plain Dart, the core dependency injection system works
the same way:

## Injecting Classes

Add the `@inject` annotation to your classes:

```dart
@inject
class DataService {
    // ...
}
```

## Using Modules for External Dependencies

For classes you don't own or need special configuration:

```dart
@module
class ApiModule {
  @provides
  @singleton
  http.Client httpClient() => http.Client();

  @provides
  ApiClient apiClient(http.Client client) => ApiClient(client);
}

// Then include the module in your component
@component([ApiModule])
abstract class AppComponent {
  // ...
}
```

# How It Works

The inject.dart system works by:

1. Analyzing your code for `@inject`, `@provides`, and other annotations at
   compile-time
2. Generating efficient factory code to create your dependencies with proper
   ordering
3. Creating a component implementation that knows how to build your dependency
   graph

All of this happens at compile-time, with no reflection or runtime overhead.

When used with Flutter through the `inject_flutter` package, the system also
provides:

- Automatic View Model creation and disposal aligned with widget lifecycle
- Automatic UI rebuilding when ViewModel state changes

## Documentation

For comprehensive documentation, visit
the [inject.dart documentation site](https://ralph-bergmann.github.io/inject.dart/).

## Additional Information

- Check the [GitHub repository](https://github.com/ralph-bergmann/inject.dart)
  for more examples and documentation
- Issues and feature requests can be filed on
  the [GitHub issue tracker](https://github.com/ralph-bergmann/inject.dart/issues)
- Contributions are welcome! Please feel free to submit a Pull Request

## FAQ

### What do you mean by compile-time?

All dependency injection is analyzed, configured, and generated at compile-time
as part of a build process, and does not rely on any runtime setup or
configuration (such as reflection with `dart:mirrors`).
This provides the best experience in terms of code-size and performance (it's
nearly identical to handwritten code) and allows us to provide compile-time
errors and warnings instead of relying on runtime.

### Why use inject.dart?

inject.dart offers several advantages:

- Zero runtime overhead with compile-time validation
- Full type-safety with clear error messages
- Clean integration with Flutter's widget lifecycle when needed
- Simple, annotation-based API with minimal boilerplate
- Modular design for organizing dependencies
