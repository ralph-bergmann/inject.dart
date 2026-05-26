# inject.dart — pub.dev Single-File Showcase

The minimal inject.dart + inject_flutter example for pub.dev.

A counter app in a single file (`lib/main.dart`) that shows the five
concepts you need to get started:

1. **`@Component` + `@module`** — declare the DI graph and provide
   external-type bindings.
2. **`@provides @singleton`** — a module-managed singleton.
3. **`@inject`** — constructor injection wired by the generator.
4. **`@assistedInject`** — compile-time DI combined with runtime parameters.
5. **`ViewModelFactory<T>`** — the `inject_flutter` bridge between DI and
   Flutter's widget lifecycle.

This file is intentionally small: it uses the same class names and domain
as the full reference example (`flutter_demo`) so that cross-references
in the comments resolve to real, matching code.

---

## Where inject.dart differs from `get_it` / `injectable`

Flutter's "apply architecture best practices" skill wires dependencies via
a runtime service locator (Step 7). inject.dart replaces that with
**compile-time constructor injection**:

- Missing bindings, cycles, and qualifier mismatches are **build errors**,
  not runtime crashes.
- There are no service-locator calls (`GetIt.I<Foo>()`) anywhere in app code.
- The generated `.inject.dart` is readable, diffable Dart — not a black box.

`get_it` resolves bindings dynamically at runtime; `injectable` generates
the registration calls into `get_it`, but runtime failures remain possible.
inject.dart generates the **entire** component implementation and catches
wiring errors at build time.

---

## For the full treatment, see `flutter_demo`

This file shows the happy path. `flutter_demo` covers everything else:

| Concept | Where in `flutter_demo` |
|---|---|
| Two-line `Qualifier` for same-type disambiguation | `lib/src/data/services/database.dart` |
| `@asynchronous` vs. raw `Future<T>` binding | `lib/src/app_module.dart` + `lib/main.dart` |
| `Provider<T>` entry point — lazy / on-demand access | `lib/main.dart` → `counterRepositoryProvider` |
| `@provisionListener` — lifecycle hook | `lib/src/app_module.dart` → `CreationLogListener` |
| Use Case layer between Repository and ViewModel | `lib/src/logic/increment_counter_use_case.dart` |
| Module override — how test components swap fakes | `test/repository_test.dart` |
| Dependency-graph visualisation (`debug_graph: true`) | `flutter_demo/build.yaml` + `flutter_demo/README.md` |

---

## Run

```shell
dart pub get
dart run build_runner build
flutter run
```

The generated files (`lib/main.inject.dart`, `lib/main.factory.dart`) are
committed so the pub.dev snapshot is self-contained and viewable without
running `build_runner`.
