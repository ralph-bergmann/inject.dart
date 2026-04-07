# Installation

Setting up inject.dart involves adding three packages and running the code
generator. This chapter walks through each step.

## Packages

| Package             | Role                                                          | Dependency type |
|---------------------|---------------------------------------------------------------|-----------------|
| `inject_annotation` | Annotations your code uses (`@inject`, `@provides`, …)       | regular         |
| `inject_generator`  | Code generator — reads annotations, emits `.inject.dart`     | **dev**         |
| `build_runner`      | Dart's standard build system; runs the generator             | **dev**         |
| `inject_flutter`    | `ViewModelFactory<T>` and `ViewModelBuilder<T>` for Flutter  | regular         |

`inject_annotation` is the only package that ships with your app.
`inject_generator` and `build_runner` are dev dependencies — they are not
included in the production build.

`inject_flutter` is optional; add it only in Flutter projects that use the
`ViewModelFactory<T>` pattern.

## Adding Dependencies

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

## Running the Code Generator

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

## Watch Mode

`build_runner` can watch for file changes and regenerate automatically:

```bash
dart run build_runner watch
```

Watch mode is convenient during development, but keep in mind:

- It holds a background process that can use significant CPU/memory in large
  projects.
- Many developers prefer explicit rebuilds — run `build_runner build` once when
  a batch of changes is complete.
- IDEs with Flutter/Dart tooling often provide a UI button that runs the build
  command for you.

## Verifying the Setup

After the first successful build you will see files like:

```
lib/main.inject.dart
lib/src/features/home/home_page.factory.dart
lib/src/features/app/my_app.factory.dart
```

These are **generated** — never edit them by hand. They are typically
git-ignored at the package level (add `*.inject.dart` and `*.factory.dart` to
`.gitignore`), with the documented exception of the pub.dev example where they
are committed so the snapshot is self-contained.

If you see an error such as `Bad state: component class must declare at least
one @inject-annotated provider`, see the Quickstart chapter's Troubleshooting
section.
