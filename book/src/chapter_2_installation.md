# Installation

To set up inject.dart, you add three packages and run the code generator.

## Packages

| Package             | Role                                                          | Dependency type |
|---------------------|---------------------------------------------------------------|-----------------|
| `inject_annotation` | Annotations your code uses (`@inject`, `@provides`, …)       | regular         |
| `inject_generator`  | Code generator: reads annotations, emits `.inject.dart`      | **dev**         |
| `build_runner`      | Dart's standard build system; runs the generator             | **dev**         |
| `inject_flutter`    | `ViewModelFactory<T>` and `ViewModelBuilder<T>` for Flutter  | regular         |

`inject_annotation` is the only package that ships with your app.
`inject_generator` and `build_runner` are dev dependencies, so they are not
part of the production build.

`inject_flutter` is optional; add it only in Flutter projects that use the
`ViewModelFactory<T>` pattern.

## Adding dependencies

### Flutter projects

```bash
flutter pub add inject_annotation inject_flutter
flutter pub add --dev inject_generator build_runner
```

Or in a single command:

```bash
flutter pub add inject_annotation inject_flutter dev:inject_generator dev:build_runner
```

### Dart-only projects (no Flutter integration)

```bash
dart pub add inject_annotation dev:inject_generator dev:build_runner
```

## Running the code generator

After annotating your classes, generate the wiring code:

```bash
dart run build_runner build
```

This processes every file with inject.dart annotations. It writes a
`.inject.dart` library next to each `@Component`, and a `.factory.dart` part
next to each file that declares an `@assistedInject` (or `@assistedFactory`)
constructor.

If output files from a previous run conflict, add `--delete-conflicting-outputs`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Watch mode

`build_runner` can watch for file changes and regenerate automatically:

```bash
dart run build_runner watch
```

Watch mode is convenient during development, but its background process can use
a lot of CPU and memory in large projects. Many developers prefer to run
`build_runner build` once when a batch of changes is complete. IDEs with
Flutter or Dart tooling often have a button that runs the build command for you.

## Verifying the setup

After the first successful build you will see files like:

```
lib/main.inject.dart
lib/src/features/home/home_page.factory.dart
lib/src/features/app/my_app.factory.dart
```

These files are generated, so never edit them by hand. Packages usually ignore
them in git (add `*.inject.dart` and `*.factory.dart` to `.gitignore`). The
pub.dev example is the exception: it commits them so the snapshot is
self-contained.

If you see an error such as `Component 'MainComponent' has no entry points`,
see the Quickstart chapter's Troubleshooting section.
