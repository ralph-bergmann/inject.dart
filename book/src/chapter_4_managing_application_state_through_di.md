# Managing Application State through Dependency Injection

After setting up the basic structure of our application with dependency
injection, we want to explore how a well-designed project structure can
work alongside state management through DI. This approach aligns with
Flutter's recommended best practices
for [app architecture](https://docs.flutter.dev/app-architecture/guide)
and [state management](https://docs.flutter.dev/data-and-backend/state-mgmt/simple).

Before we dive into state management, let's refactor our application to
better separate concerns by extracting the app and home widgets into their
own files. This restructuring will provide a cleaner foundation for
implementing state management through dependency injection.

## Refactoring the Application Structure

First, let's reorganize our code to separate the UI components from the
dependency injection setup. This creates a more maintainable architecture
as our application grows.

### Extracting Widgets into Feature-Based Files

We'll extract our widgets from `main.dart` into separate files using a
feature-based organization:

1. Create a `src/features/app` directory for the application widget
2. Create a `src/features/home` directory for the home page widget
3. Move relevant code while maintaining dependencies and annotations

Here's how we'll refactor each file:

1. **main.dart** - Will contain only the DI setup and application entry
   point:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'main.inject.dart' as g;
import 'src/features/app/app.dart';

void main() {
  final mainComponent = MainComponent.create();
  final app = mainComponent.myAppFactory.create();
  runApp(app);
}

@component
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;
}
```

2. **my_app.dart** - Contains the app widget and its factory:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../home/home.dart';

@assistedFactory
abstract class MyAppFactory {
  MyApp create({Key? key});
}

class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({@assisted super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
```

3. **my_home.dart** - Contains the home page widget:

```dart
import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
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
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
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
}
```

This refactoring creates a cleaner, more scalable project structure with
these technical benefits:

1. **Separation of Concerns**: Each file now has a distinct responsibility
2. **Improved Maintainability**: Changes to one feature won't affect files
   for other features
3. **Better Dependency Management**: Import paths clearly show dependencies
   between features
4. **Enhanced Discoverability**: New team members can quickly locate
   components by feature
5. **DI-Friendly Organization**: Structure supports targeted injection of
   dependencies where needed

The resulting directory structure looks like this:

```
flutter_demo/
└── lib/
    ├── main.dart                 (DI setup and entry point)
    └── src/
        └── features/
            ├── app/
            │   └── my_app.dart   (MyApp and MyAppFactory)
            └── home/
                └── my_home.dart  (MyHomePage)
```

With this structure in place, we're now ready to implement state management
through dependency injection.

## Implementing State Management with Dependency Injection

Now that we have a clean project structure, we'll implement state
management using dependency injection principles. Our architecture will
introduce two new components: a `CounterRepository` for data persistence
and a `MyHomePageViewModel` to connect the UI with this data layer.

The `CounterRepository` will handle the persistence of our counter value.
It will provide methods to store and retrieve the counter, effectively
abstracting the storage mechanism from the rest of the application. This
abstraction is powerful because it allows us to change the underlying
storage implementation without affecting the components that use it.

The `MyHomePageViewModel` will serve as an intermediary between our UI and the
data layer. It will depend on the `CounterRepository` (injected through our
DI system) and provide the UI with the state and methods it needs. This
creates a clean separation between how data is presented and how it's
stored or processed.

This architecture demonstrates one of the key benefits of dependency
injection: the ability to create a system where components depend on
abstractions rather than concrete implementations. When the
`MyHomePageViewModel` receives its `CounterRepository` through injection, it
doesn't need to know the details of how the repository is implemented or
how it's instantiated.

This separation creates more maintainable code because changes to one layer
don't necessarily affect others. It also dramatically improves testability
since each component can be tested in isolation with mock implementations
of its dependencies. The repository could be reused across different
features if needed, showcasing how DI promotes code reuse through proper
component design.

After refactoring our application to use the `MyHomeViewModel` and the
`CounterRepository` for handling the counter value, the project structure
now looks like this:

```
flutter_demo/
└── lib/
    ├── main.dart                                (DI setup and entry point)
    └── src/
        ├── data/
        │   ├── repositories/
        │   │   └── counter_repository.dart      (Manages counter state)
        │   └── services/
        │       └── database.dart                (Simulated database service)
        └── features/
            ├── app/
            │   └── my_app.dart                  (MyApp and MyAppFactory)
            └── home/
                ├── my_home_page.dart            (MyHomePage UI component)
                └── my_home_page_view_model.dart (Home state management)
```

### Making MyHomePage Injectable

To make our home page injectable, we create a factory that allows the DI system
to instantiate it:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

/// Factory to create the [MyHomePage] widget with its dependencies.
@assistedFactory
abstract class MyHomePageFactory {
  MyHomePage create({Key? key, required String title});
}

/// The home page of the application with a simple counter.
class MyHomePage extends StatelessWidget {
  @assistedInject
  const MyHomePage({
    @assisted super.key,
    @assisted required this.title,
  });

// Widget implementation...
}
```

1. We've created a factory (`MyHomePageFactory`) that allows the DI system
   to create instances of `MyHomePage` with all dependencies properly
   injected.

2. We use `@assistedInject` to mark the constructor as an injection point,
   while marking runtime parameters like `key` and `title` with
   `@assisted`.

3. Notice that we also changed it to be a `StatelessWidget` instead of a
   `StatefulWidget`. When we later add the view model, we'll see how we
   use the view model to manage the state of the widget.

### Connecting MyHomePage to MyApp

In the `MyApp` widget, we inject the `MyHomePageFactory` and use it to
create the home page:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../home/my_home_page.dart';

/// Factory to create the [MyApp] widget with the [MyHomePageFactory] injected.
@assistedFactory
abstract class MyAppFactory {
  MyApp create({Key? key});
}

/// The root widget of the application.
/// The [MyHomePageFactory] is injected into the widget at compile-time.
class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({
    @assisted super.key,
    required this.homePageFactory,
  });

  final MyHomePageFactory homePageFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: homePageFactory.create(title: 'Flutter Demo Home Page'),
    );
  }
}
```

This structure creates a clean dependency chain:

1. The `MyApp` widget depends on `MyHomePageFactory` (injected)
2. The `homePageFactory.create()` method is called to instantiate the home page

This approach demonstrates nested widget creation through dependency injection,
allowing each component to receive its required dependencies.

By using factories, we ensure proper dependency injection throughout our
widget tree while still allowing for runtime parameters like `title` and
`key`.
This approach gives us the best of both worlds: compile-time dependency
injection with runtime flexibility.

## Adding State Management with ViewModel

Now that we have our basic widget structure with dependency injection, we need
to implement state management. We'll use a ViewModel approach that provides a
clean separation between UI and business logic.

### Creating the ViewModel

First, let's create a ViewModel class that handles the state and business logic
for our counter feature:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../../data/repositories/counter_repository.dart';
import 'my_home_page.dart';

/// The view model for the [MyHomePage] widget.
@inject
class MyHomePageViewModel extends ChangeNotifier {
  MyHomePageViewModel({required CounterRepository repository})
      : _repository = repository;

  final CounterRepository _repository;

  int count = 0;

  Future<void> increaseCount() async {
    await _repository.increaseCount();
    count = await _repository.count;
    notifyListeners();
  }
}
```

The ViewModel has these important characteristics:

1. It's marked with `@inject` so it can be created by the DI system
2. It extends `ChangeNotifier` to provide change notifications to the UI
3. It depends on `CounterRepository`, which is injected through its constructor
4. It manages state (the count variable) and provides a method to update it
5. It calls `notifyListeners()` when the state changes to trigger UI updates

This pattern creates a clear separation of concerns:

- The ViewModel handles business logic and state management
- The repository handles data operations
- The UI focuses solely on presentation

Note the constructor implementation pattern:

```dart
MyHomePageViewModel({required CounterRepository repository})
      : _repository = repository;

final CounterRepository _repository;
```

Rather than using the more concise `this.repository` syntax and a public field, 
we deliberately use a private field with manual assignment to enforce strict 
encapsulation. This approach provides significant architectural benefits:

1. **True Encapsulation**: Dependencies like `_repository` remain truly private.
   If we use a public field, any component that received the ViewModel could 
   potentially access its repository directly. This would violate the
   encapsulation principle and make it difficult to change the implementation
   later without breaking existing code.

2. **Preventing Dependency Leakage**: When a view model is injected into a UI
   component, we want to ensure the UI can only access the intended public API.
   Manual assignment to private fields creates a clear boundary that prevents
   dependency leakage across architectural layers.

3. **Layer Isolation**: This pattern supports the principle that each layer
   should only know about its immediate dependencies. The UI knows about the
   ViewModel but should have no knowledge of or access to the repositories or
   services the ViewModel uses.

This small syntax choice reinforces an important architectural principle:
components should expose only what their consumers need and nothing more,
maintaining clear boundaries between different layers of the application.

### Injecting the ViewModel with ViewModelFactory

Now, let's update our MyHomePage to use this ViewModel with the ViewModelFactory
pattern:

```dart
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
```

### How ViewModelFactory Works

The `ViewModelFactory<T>` is a typedef for a function that returns a
`ViewModelBuilder<T>`:

```dart
typedef ViewModelFactory<T extends ChangeNotifier> = ViewModelBuilder<T> Function({
   Key? key,
   required ViewModelWidgetBuilder<T> builder,
   Widget? child,
});
```

When you call this function in the build method, it:

1. **Creates a ViewModelBuilder**: This StatefulWidget handles the ViewModel
   lifecycle
2. **Passes Your Builder Function**: Your UI-building logic receives the
   ViewModel instance
3. **Manages ViewModel Creation**: The ViewModel is created when the
   ViewModelBuilder first builds
4. **Handles ViewModel Disposal**: When the ViewModelBuilder is disposed, it
   disposes the ViewModel

The builder function pattern provides a clean way to access the ViewModel's
state and methods inside your UI code. By using this approach:

1. The UI reacts to changes in the ViewModel automatically
2. Business logic stays in the ViewModel
3. The widget remains a simple StatelessWidget
4. Lifecycle management happens behind the scenes

This creates a maintainable architecture where each component has a clear
responsibility.

## Data Layer: Repository and Database

Let's explore how we implement dependency injection for our data layer
components.

### The Repository Pattern

Our `CounterRepository` acts as a mediator between the UI layer and the
data storage:

```dart 
import 'package:inject_annotation/inject_annotation.dart';

import '../services/database.dart';

/// Repository to manage the counter value.
/// Uses the [Database] to persist the counter value.
@inject
@singleton
class CounterRepository {
  CounterRepository({required Database database}) : _database = database;

  final Database _database;

  Future<int> get count async => _database.selectCount();

  Future<void> increaseCount() async {
    final count = await _database.selectCount();
    await _database.updateCount(count + 1);
  }
}
```

Notice the `@singleton` annotation - this tells our DI system to create
only one instance of the repository throughout the application.
This is crucial because:

1. We want a single source of truth for data operations
2. It ensures consistent state management across the application
3. It avoids redundant database connections

The repository depends on the `Database`, which is injected through its
constructor.
This creates a clean separation between data access logic and storage
implementation.

### Providing the Database Through a Module

Since we are using a database from a third-party library that we cannot
annotate with `@inject`, we use a module to provide it:

```dart 
import 'package:inject_annotation/inject_annotation.dart';

/// Module to provide the database instance.
/// Modules are used to provide instances of classes from 3rd party libraries
/// that can't be annotated with [inject].
@module
class DataBaseModule {
  @provides
  @singleton
  Database provideDatabase() => Database();
}

/// Simulates a 3rd party database library for demonstration purposes.
///
/// This class mimics what you might find in an actual database package
/// like Drift, Isar, or Hive, but with simplified functionality to focus
/// on dependency injection concepts. In a real app, you would replace this
/// with an actual database implementation.
///
/// Usage example:
/// ```dart
/// final db = Database();
/// await db.updateCount(5);
/// final value = await db.selectCount(); // Returns 5
/// ```
class Database {
  /// In-memory storage for the counter value.
  /// In a real database, this would be persisted to disk.
  int _count = 0;

  /// Simulates updating a record in the database.
  ///
  /// In a real database, this would write to persistent storage.
  Future<void> updateCount(int count) async {
    _count = count;
  }

  /// Simulates reading a record from the database.
  ///
  /// In a real database, this would fetch data from persistent storage.
  Future<int> selectCount() {
    return Future.value(_count);
  }
}
```

The `@module` annotation defines a class that provides dependencies.
The `@provides` method tells inject.dart how to create an instance of the
`Database` class.
By adding the `@singleton` annotation, we ensure only one
database instance exists in our application.

This approach demonstrates how to integrate third-party libraries into your
dependency injection system, even when you can't modify their source code.

### ViewModels: Why They're Not Singletons

In contrast to the repository and database, view models are deliberately
**not** marked as singletons.
This is an important architectural decision:

1. **Lifecycle Alignment**: Each view should have its own view model
   instance that matches its lifecycle
2. **State Isolation**: Different instances of the same view should have
   isolated state
3. **Memory Efficiency**: View models can be garbage collected when their
   associated view is disposed

If view models were singletons, all instances of a view would share the
same state, creating unexpected behavior and potential memory leaks. By
making each view model instance-specific while keeping the data layer as
singletons, we create a clean hierarchy where stable infrastructure is
shared while UI state remains isolated.

This pattern demonstrates a key strength of dependency injection: the
ability to configure different scopes for different types of components in
your application.

## Conclusion

In this chapter, we've explored how dependency injection naturally
complements state management in Flutter applications. By separating our
application into clean layers — UI components, ViewModels, repositories, and
services — we've created a maintainable architecture that's both flexible and
testable.

The key principles we've covered include:

1. Using dependency injection to provide state management services
2. Creating a clear separation between UI and business logic
3. Implementing proper lifecycle management with ViewModelFactory
4. Leveraging singletons for shared infrastructure like repositories and
   databases

### Complete Example

You can find the complete source code for all examples in this chapter in
the [
`examples/flutter_demo`](https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo)
folder of the inject.dart repository. This working implementation
demonstrates all the patterns and practices we've discussed.

### Coming Next: Testing with Dependency Injection

In the next chapter, we'll explore one of the most powerful benefits of our
architecture: testability. We'll show how to create a separate dependency
graph for unit testing that allows us to:

1. Test ViewModels by injecting mock repositories
2. Test repositories with a FakeDatabase implementation
3. Write integration tests that validate the entire dependency chain
4. Create targeted tests that focus on specific components

This testing approach demonstrates how dependency injection doesn't just
make your code more maintainable — it makes it substantially easier to verify
and validate your application's behavior through automated testing.

By separating concerns and making dependencies explicit, we've built a
foundation that will continue to pay dividends as your application grows in
complexity.
