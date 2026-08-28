# bookshelf — Multi-Package inject.dart Example

A small "sign in, see your books" app split across three plain-Dart
packages and one Flutter app — a realistic shape for a monorepo, not a
single-file toy. If you want the compact single-file showcase, see
[`example`](../example/README.md); for the full layered-architecture demo,
see [`flutter_demo`](../flutter_demo/README.md). This example's job is the
**composition** story: a shared kernel, cross-package bindings, and a
session graph created at login and dropped at logout.

---

## Package layout

```
                ┌── bookshelf_api ──┐
bookshelf_core ─┤                   ├── app (bookshelf)
                └── bookshelf_auth ─┘
                       ↑
                bookshelf_auth also depends on bookshelf_api directly
```

Everything fans out from `bookshelf_core`; `bookshelf_auth` depends on both
`bookshelf_core` **and** `bookshelf_api` directly (not just transitively),
and the app depends on all three:

| Package         | Depends on              | Ships                                                              |
|-----------------|--------------------------|--------------------------------------------------------------------|
| `bookshelf_core`| —                        | `Logger`/`ConsoleLogger`, models (`User`, `Credentials`, `Book`), `CoreModule` |
| `bookshelf_api` | `bookshelf_core`         | `BooksApi` (fake backend), `ApiModule` (needs a base URL — no default constructor) |
| `bookshelf_auth`| `bookshelf_core`, `bookshelf_api` | `AuthRepository`, `AuthModule`                             |
| `bookshelf` (app)| all three               | `MainComponent`, the session subcomponent, and every UI widget      |

Only the app has `inject_generator`/`build_runner` as dev dependencies. The
three packages ship annotated classes (`@inject`, `@module`) but run no code
generation themselves — their bindings resolve into the app's
`main.inject.dart`, exactly like `flutter_demo`'s `counter_analytics`
package.

---

## What this app demonstrates

| Concept                                              | Where                                                    |
|-------------------------------------------------------|-----------------------------------------------------------|
| Shared kernel, listed once                             | `lib/main.dart` → `MainComponent([CoreModule, ...])`      |
| Cross-package binding (no module knows the other)      | `packages/bookshelf_auth/lib/src/auth_module.dart`         |
| Runtime config via a module with no default constructor| `packages/bookshelf_api/lib/src/api_module.dart` → `ApiModule` |
| Session subcomponent, installed via a module           | `lib/src/app/app_module.dart` → `AppModule`                |
| `@subcomponentFactory` value parameter (`Credentials`)  | `lib/src/session/session_component.dart` → `SessionComponentFactory` |
| Session-private singleton, fresh per login              | `lib/src/session/book_repository.dart` → `BookRepository`  |
| `@assistedInject` view + `ViewModelFactory<T>`          | `lib/src/session/home_page.dart`, `lib/src/login/login_page.dart` |
| Session lifecycle owner (`inject_flutter`'s `SubcomponentBuilder`) | `lib/src/login/auth_gate.dart`                 |
| Test-parent seam (swap one module, keep the rest)       | `test/test_component.dart`                                 |

### Shared kernel, one listing

`CoreModule` provides the single `Logger` singleton every other module
depends on. It is listed exactly once, in `MainComponent`:

```dart
@Component([CoreModule, ApiModule, AuthModule, AppModule])
abstract class MainComponent { ... }
```

`bookshelf_api` and `bookshelf_auth` both inject `Logger` — neither
re-lists `CoreModule` itself. Re-listing a package's dependency's module
would build a *second*, independent `Logger` instance (singletons are
scoped per component, not per module) — the anti-pattern this example
deliberately avoids.

### Runtime configuration through a required module parameter

`ApiModule` has no default constructor:

```dart
const ApiModule(this.baseUrl);
```

so the generated factory makes it a **required** named parameter —
`MainComponent.create(apiModule: ...)` does not compile without one:

```dart
MainComponent.create(apiModule: const ApiModule('https://bookshelf.example.com'));
```

### Session subcomponent

Logging in creates a session — an encapsulated child graph whose bindings
never touch the root:

```dart
@Subcomponent([SessionModule])
abstract class SessionComponent {
  HomePageFactory get homePageFactory;
  BookRepository get bookRepository; // exposed for the test seam
}

@subcomponentFactory
abstract class SessionComponentFactory {
  SessionComponent create(Credentials credentials);
}
```

The hand-declared `@subcomponentFactory` replaces the factory the generator
would otherwise synthesize, and its `Credentials` parameter is a **value
parameter**: the instance passed to `create` becomes a binding in the
session graph, injectable by anything inside it —
`SessionModule.provideBookRepository` consumes it like any other dependency.
Note the contrast with `ApiModule(baseUrl)` above: a module constructor
carries configuration fixed once when the graph is built, while a factory
value parameter carries a runtime value that is different for every session.

`AuthGate` owns the session's lifetime with `inject_flutter`'s
`SubcomponentBuilder<SessionComponent>`, mounted below the login/logout
branch point only once a login succeeds:

```dart
Widget build(BuildContext context) {
  final Credentials? credentials = _credentials;
  if (credentials == null) {
    return widget.loginPageFactory.create(onLoggedIn: _onLoggedIn);
  }
  return SubcomponentBuilder<SessionComponent>(
    key: ValueKey(credentials),
    create: () => widget.sessionFactory.create(credentials),
    builder: (context, session, _) => session.homePageFactory.create(onLogout: _logout),
  );
}
```

Every login builds a fresh `SessionComponent` instance with its own
`@singleton BookRepository` — `SubcomponentBuilder` calls `create` exactly
once, in `initState`, and the `key: ValueKey(credentials)` guarantees a
fresh `State` (and therefore a fresh `SessionComponent`) for every login,
even a repeat login with the same username/password. Logging out sets
`_credentials` back to `null`, unmounting the `SubcomponentBuilder`
subtree — nothing disposes anything explicitly, since `Credentials` and
`BookRepository` were never bindings in the root graph, so once the
`SessionComponent` reference is gone, so are they.

### Test-parent seam

`test/test_component.dart` swaps `ApiModule` for `FakeApiModule` while
reusing `AuthModule` and `AppModule` unchanged — the same session-install
point production uses:

```dart
@Component([CoreModule, FakeApiModule, AuthModule, AppModule])
abstract class TestComponent { ... }
```

Note this isn't "fake standing in for real" in the usual sense: `BooksApi`
(production) is *already* an in-memory fake that simulates network latency
with `Future.delayed`. `test/fake_books_api.dart`'s `FakeBooksApi` is a
second, test-only fake that swaps that one out for something deterministic
and instant — no delays, no clock — while keeping the exact same contract
(including throwing on a wrong password, so login-failure tests exercise
the real error path).

A session created under `TestComponent` observes the fake backend through
the child graph automatically — `SessionModule` and `AppModule` never
needed to know a test was running. `TestComponent` also exposes an extra
`@inject SessionComponentFactory get sessionFactory;` entry point that
production's `MainComponent` doesn't need — it lets
`test/session_seam_test.dart` drive the subcomponent directly and inspect
`BookRepository`, without pumping a full widget tree.

See `test/session_seam_test.dart` (unit test) and `test/login_flow_test.dart`
(widget test, login → book list → logout, all against the fake backend).

---

## Run

```shell
dart pub get
dart run build_runner build
flutter run
```

`build_runner` generates `lib/main.inject.dart` and the `*.factory.dart`
part files next to the widgets that declare `@assistedInject` —
`auth_gate.factory.dart`, `login_page.factory.dart`, and
`home_page.factory.dart`. The session needs no such part file:
`SessionComponentFactory` is declared by hand in
`lib/src/session/session_component.dart`, and its implementation is wired
up inside `main.inject.dart`.

Sign in as `alice` / `hunter2` (or `bob` / `letmein`) — both are canned in
`BooksApi`'s in-memory user directory.

## Test

```shell
flutter test
```

Runs `test/session_seam_test.dart` (unit test: a session created under
`TestComponent` observes the fake backend, and each login gets its own
fresh `BookRepository` singleton) and `test/login_flow_test.dart` (widget
test: login → book list → logout, plus a wrong-password case that stays on
the sign-in form) against the fake backend.
