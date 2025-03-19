# Quickstart Guide

This chapter provides a hands-on introduction to using inject.dart in a
real Flutter project. We'll build a simple application from scratch to
demonstrate how dependency injection works in practice.

By the end of this chapter, you'll understand how to:

- Set up a Flutter project with inject.dart
- Define injectable classes and providers
- Create and use a component
- Access your dependencies throughout the application

Let's begin by creating a new Flutter project which provides a minimal
starting point without unnecessary boilerplate
code:

```bash
flutter create -flutter_demo
```

This creates a basic Flutter project structure with just the essential
files. Next, let's navigate into the project directory:

```bash
cd flutter_demo
```

Now we're ready to start implementing dependency injection with
inject.dart!

## Adding Dependencies

First, we need to add inject.dart and related packages to our project:

```bash
flutter pub add inject_annotation dev:inject_generator dev:build_runner
```

This command adds three important packages:

- `inject_annotation`: The core package that provides annotations like
  `@inject`, `@provides`, and `@singleton`
- `inject_generator`: The code generation package that processes the
  annotations and generates the dependency injection code
- `build_runner`: Dart's standard build system that runs the code
  generators

The `dev:` prefix indicates that inject_generator and build_runner are
development dependencies, which means they're only used during development
and won't be included in your production app.

After running this command, you should see the dependencies added to your
`pubspec.yaml` file. The next step is to create our first injectable
classes!

## Creating the Component

After adding dependencies, our first step is to create the root component
that will serve as the entry point for our dependency graph.

In dependency injection, a component acts as a container that knows how to
create and provide the objects in your application. Let's create our
`MainComponent` in the main.dart file:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

void main() {
  // We'll update this later to use our component
  // For now, keep the default main method
  runApp(const MyApp());
}

@component
abstract class MainComponent {
  @inject
  MyAppFactory get myAppFactory;
}
```

This `MainComponent` is the root of our dependency graph. The `@component`
annotation tells inject.dart that this class will be our dependency
container. Inside the component, we define methods that return the types we
want to inject, like `MyAppFactory`.

## Creating a Factory for MyApp

Next, we need to create a factory for our main application widget. Add the
`MyAppFactory` class above the `MyApp` widget and add the `@assistedInject`
and `@assisted` annotations to the `MyApp` class:

```dart
@assistedFactory
abstract class MyAppFactory {
  MyApp create({Key? key});
}

class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({@assisted super.key});

// the rest remains unchanged for now
}
```

These annotations tell inject.dart how to create instances of `MyApp`:

- `@assistedFactory` creates a factory interface that will instantiate
  `MyApp` with its dependencies
- `@assistedInject` marks the constructor as the injection point
- `@assisted` indicates parameters that are provided at runtime rather than
  from the dependency graph

Here, we're using `@assistedInject` to create a factory for our `MyApp`
widget. This special annotation generates a factory that can create `MyApp`
instances with both injected dependencies (which we'll add later) and
runtime parameters (like `key`).

The `MyAppFactory` will allow us to create `MyApp` instances with all
necessary dependencies automatically injected, while still allowing us to
pass in runtime values like the optional `key` parameter.

## Generating the Code

Now that we've set up our component and factory, it's time to generate the
actual dependency injection code:

```bash
dart run build_runner build
```

This command processes our annotations and generates the necessary
implementation code. If successful, you'll see output indicating that files
were generated, including `main.inject.dart`.

Once the generation is complete, we need to import the generated code and
add a convenience factory method to our component:

```dart
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

// Import the generated code with a prefix
import 'main.inject.dart' as g;

void main() {
  // We'll update this later to use our component
  // For now, keep the default main method
  runApp(const MyApp());
}

@component
abstract class MainComponent {
  // Add a static factory method that references the generated code
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;
}
```

The `g.MainComponent$Component.create` reference points to the actual
component implementation generated by inject.dart. By adding this static
factory method, we make it easy to instantiate our component elsewhere in
the code without needing to directly reference the generated file.

This pattern gives us a clean API while keeping the implementation details
hidden in the generated code. The `g` prefix helps distinguish between our
code and the generated code.

## Troubleshooting the Code Generation

### Bad state

When running the code generator, you might encounter this error:

```
Bad state: package:flutter_demo/main.dart:
   component class must declare at least one @inject-annotated provider
```

This happens because a component must provide at least one injectable type.
To fix this, make sure you've added the `@inject` annotation to at least
one getter in your component:

```dart
@component
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;
}
```

The `@inject` annotation tells inject.dart that this getter should be
treated as a provider method. Every component needs at least one provider
to be valid, as a component without providers wouldn't serve any purpose in
a dependency injection system.

### Could not find a way to provide

Another possible error you might encounter is:

```
Could not find a way to provide "MyAppFactory" for component "MainComponent".
```

This error occurs when inject.dart can't figure out how to create an
instance of the type your component is trying to provide. In this specific
case, it happens because the `@assistedInject` annotation is missing from
the `MyApp` constructor.

`MainComponent` is trying to provide `MyAppFactory`, but inject.dart
doesn't know how to create it because there's no constructor marked with
`@assistedInject` that matches the factory's creation method signature.

Remember that for assisted injection to work properly:

1. The abstract factory must be annotated with `@assistedFactory`
2. The class constructor must be annotated with `@assistedInject`
3. Runtime parameters must be annotated with `@assisted`

All three parts need to be present for the code generator to successfully
create the implementation.

## Using the Component

With our dependency injection setup complete and code generated, we can now
use the component to create an instance of our app:

```dart
void main() {
  final mainComponent = MainComponent.create();
  final app = mainComponent.myAppFactory.create();
  runApp(app);
}
```

This three-line implementation achieves several important things:

1. It initializes our dependency graph by creating the `MainComponent`
2. It uses the component to get the `MyAppFactory` and create our app
   instance
3. It ensures all dependencies are properly injected throughout the
   application

This approach provides a clear entry point for our dependency injection
system. The component acts as the "source of truth" for all dependencies,
and by using it to create our app, we establish a clean architectural
boundary that makes our code more maintainable and testable.

As we add more dependencies to our application, they'll automatically be
injected without any changes needed to this initialization code. This is
the power of using a well-structured dependency injection system — the
application startup remains clean while the dependency graph can grow more
complex beneath the surface.

## Conclusion

In this chapter, we've covered the fundamentals of setting up inject.dart
in a Flutter application. You've learned how to:

1. Set up a new Flutter project with the necessary dependencies
2. Create a component to serve as the root of your dependency graph
3. Define injectable factories and classes
4. Generate the dependency injection code
5. Use the component to create and inject dependencies

## Complete Example

You can find the complete source code for this quickstart guide in the
[`examples/flutter_demo`](https://github.com/ralph-bergmann/inject.dart/tree/master/examples/flutter_demo)
folder of the inject.dart repository.
This example contains all the code we've discussed
in this chapter, properly structured and ready to run.

Reviewing the complete example may help solidify your understanding of how
all the pieces fit together in a working application.

### Coming Next: Managing Application State

In the next chapter, we'll build on these fundamentals by exploring how to
manage application state through dependency injection. We'll refactor our
application to follow best practices for state management, introducing
repositories, view models, and services that work together through injected
dependencies.

This more advanced implementation will demonstrate how dependency injection
facilitates clean architecture by separating concerns and making
dependencies explicit, resulting in code that's more maintainable,
testable, and scalable.
