# Installation

Setting up inject.dart in your project involves adding the necessary
dependencies and configuring the build runner. This chapter will guide you
through the process step by step.

## Adding Dependencies

To use inject.dart in your Dart or Flutter project, you need to add two
dependencies:

1. `inject_annotation` - Contains the annotations you'll use in your code
2. `inject_generator` - Handles the code generation based on your
   annotations

You'll also need the `build_runner` package, which is the standard Dart
tool for generating code.

### For Dart Projects

```bash
dart pub add inject_annotation dev:inject_generator dev:build_runner
```

### For Flutter Projects

```bash
flutter pub add inject_annotation dev:inject_generator dev:build_runner
```

Note that `inject_generator` and `build_runner` are added as dev
dependencies since they're only needed during development and not at
runtime.

## Running the Code Generator

After adding the dependencies and writing code with the appropriate
annotations (which we'll cover in subsequent chapters), you need to run the
build_runner to generate the necessary code:

```bash
dart run build_runner build
```

## Using the Watch Command

The build_runner tool offers a `watch` command that automatically
regenerates code when it detects changes:

```bash
dart run build_runner watch
```

### A Note on Watch Mode

While the watch command can be convenient for smaller projects, there are
some considerations to keep in mind:

- **Resource Usage**: The watch command keeps a process running in the
  background, which consumes system resources. In larger projects, this can
  potentially impact development machine performance.

- **Change Detection**: In large projects with many files, the
  file-watching mechanism may cause unnecessary rebuilds or occasionally
  miss changes, requiring manual intervention.

- **IDE Integration**: Many IDEs now have built-in support for running
  build_runner commands, which can provide a more controlled alternative to
  continuous watching.

- **Build Efficiency**: It often makes more sense to rebuild the code
  manually when all changes are done instead of regenerating it for each
  tiny change. This approach can save considerable time and resources,
  especially when making multiple related changes to your dependency
  structure.

Many developers prefer to explicitly run the build command when needed,
especially in larger projects. This gives you more control over when code
generation happens and can lead to a smoother development experience.
