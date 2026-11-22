# inject_lints

Analyzer plugin for [inject.dart](https://github.com/ralph-bergmann/inject.dart).

The inject.dart code generator checks your annotations and stops the build when
something is wrong. `inject_lints` runs many of these checks in the analyzer, so
you see the problem in the IDE while you type, before you run `build_runner`.
It also offers optional style rules.

The diagnostics show up in the IDE and in `dart analyze` and `flutter analyze`.
The plugin needs Dart 3.13 or newer.

## Set up

Add the plugin to the `analysis_options.yaml` at the root of your package or
workspace:

```yaml
plugins:
  inject_lints: ^0.1.0
```

You do not add `inject_lints` to `pubspec.yaml`. The analysis server fetches
the plugin itself. Restart the analysis server after you change the `plugins`
section. In VS Code, run **Dart: Restart Analysis Server**.

The plugin must be in the root `analysis_options.yaml`. The analyzer ignores a
`plugins` section in a nested options file.

This enables the [checks](#checks). To also enable the [style rules](#style-rules),
list them under `diagnostics`:

```yaml
plugins:
  inject_lints:
    version: ^0.1.0
    diagnostics:
      prefer_single_entry_point: true
      avoid_generated_component: true
      prefer_inject_over_provides: true
      prefer_injected_widget: true
      avoid_inline_qualifier: true
      avoid_manual_view_model_builder: true
```

To turn off a rule, checks included, set it to `false`:

```yaml
plugins:
  inject_lints:
    version: ^0.1.0
    diagnostics:
      require_provides_annotation: false
```

To use a local copy of the plugin, give a `path` instead of a `version`:

```yaml
plugins:
  inject_lints:
    path: /absolute/path/to/inject.dart/packages/inject_lints
```

To suppress a single diagnostic, name the plugin and the rule:

```dart
// ignore: inject_lints/avoid_qualified_and_unqualified_provider
// ignore_for_file: inject_lints/prefer_single_entry_point
```

## Rules

A rule name starts with `require_` for something inject.dart needs, with
`prefer_` for something you should do, and with `avoid_` for something you
should not do.

### Checks

The checks are on by default. Each one reports code that the generator rejects
or ignores. An error means the build would fail. A warning means the build
works, but probably not the way you want.

| Rule | Severity | Reports |
|---|---|---|
| [`require_abstract_component`](#require_abstract_component) | warning | A component class that is not `abstract` |
| [`avoid_inject_constructor_in_component`](#avoid_inject_constructor_in_component) | error | An injected constructor in a `@Component` class |
| [`require_public_module`](#require_public_module) | error | A private `@module` class |
| [`require_provides_annotation`](#require_provides_annotation) | warning | A public module method without `@provides` |
| [`require_valid_module_list`](#require_valid_module_list) | error | A wrong entry in a module or subcomponent list |
| [`require_provision_listener_type`](#require_provision_listener_type) | error | A `@provisionListener` method that returns no `ProvisionListener` |
| [`avoid_qualified_and_unqualified_provider`](#avoid_qualified_and_unqualified_provider) | warning | A module that provides a type with and without a qualifier |
| [`require_unambiguous_inject_constructor`](#require_unambiguous_inject_constructor) | error | A class whose injected constructor inject.dart cannot pick |
| [`avoid_asynchronous_on_inject`](#avoid_asynchronous_on_inject) | warning | `@asynchronous` on an injected class or constructor |
| [`require_assisted_parameter`](#require_assisted_parameter) | error | An `@assistedInject` constructor without `@assisted` parameter |
| [`require_valid_factory`](#require_valid_factory) | error | An `@assistedFactory` or `@subcomponentFactory` the generator rejects |

Some checks offer a quick fix in the IDE:

| Rule | Quick fix |
|---|---|
| `require_abstract_component` | Add `abstract` |
| `avoid_inject_constructor_in_component` | Remove `@inject` or `@assistedInject` from the constructor |
| `require_provides_annotation` | Add `@provides` |
| `require_valid_module_list` | Remove a duplicate entry |
| `avoid_asynchronous_on_inject` | Remove `@asynchronous` |
| `require_assisted_parameter` | Replace `@assistedInject` with `@inject` |
| `require_valid_factory` | Add `abstract`, if the factory class is not abstract |

`dart fix` does not apply these fixes, because the analyzer cannot apply plugin
fixes in bulk. The IDE can apply a fix to every match in a file at once,
except the fix for a duplicate entry.

The checks look at one file at a time. The generator still reports the
problems that need the whole dependency graph: a missing binding, a duplicate
binding, a dependency cycle, a mismatch between `Future` and the async chain,
and a subcomponent that no module installs.

### Style rules

The style rules are off by default. Enable the ones you want.

| Rule | Reports |
|---|---|
| [`prefer_single_entry_point`](#prefer_single_entry_point) | Every entry point of a component after the first |
| [`avoid_generated_component`](#avoid_generated_component) | The generated `X$Component` class used outside the component |
| [`prefer_inject_over_provides`](#prefer_inject_over_provides) | A provider for a class that can carry `@inject` itself |
| [`prefer_injected_widget`](#prefer_injected_widget) | A public widget that takes injectable types but is not injected |
| [`avoid_inline_qualifier`](#avoid_inline_qualifier) | `@Qualifier(#name)` written directly as an annotation |
| [`avoid_manual_view_model_builder`](#avoid_manual_view_model_builder) | A `ViewModelBuilder` constructed by hand |

## Components

### require_abstract_component

A class annotated with `@Component` or `@Subcomponent` must be `abstract`.
inject.dart generates the implementation.

```dart
@component
class MainComponent {} // reported

@component
abstract class MainComponent {} // ok
```

Skill: [inject-annotation-setup-di][setup-di]

### avoid_inject_constructor_in_component

A `@Component` class must not have an `@inject` or `@assistedInject`
constructor. inject.dart generates the component. The annotation belongs on
the classes that the component provides.

```dart
@component
abstract class MainComponent {
  @inject
  MainComponent(); // reported
}
```

Skill: [inject-annotation-setup-di][setup-di]

### prefer_single_entry_point

Style rule. A component should expose one type. The rule reports every entry
point after the first. An entry point is a getter or method that is abstract or
annotated with `@inject`.

```dart
@Component([AppModule])
abstract class MainComponent {
  @inject
  MyAppFactory get myAppFactory; // ok

  @inject
  CounterRepository get counterRepository; // reported
}
```

A common choice is the factory of the root widget, which gets everything else
through injection.

The rule does not count entry points that a component inherits from a
supertype. A test component often needs several entry points, so suppress the
rule in test code.

### avoid_generated_component

Style rule. Create a component through its own `create`, not through the
generated class. The rule reports every use of `X$Component` outside the
component class `X`.

```dart
@Component([AppModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create; // ok
}

final component = g.MainComponent$Component.create(); // reported
final component = MainComponent.create(); // ok
```

Skill: [inject-annotation-setup-di][setup-di]

## Modules

### require_public_module

A `@module` class must be public. The generated component lives in a separate
library and cannot create a private class.

```dart
@module
class _AppModule {} // reported
```

Skill: [inject-annotation-create-module][create-module]

### require_provides_annotation

Every public instance method of a `@module` class must be annotated with
`@provides`. inject.dart skips a method without the annotation and prints no
message, so the binding is missing from the graph.

```dart
@module
class AppModule {
  @provides
  Dio provideDio() => Dio(); // ok

  ApiClient provideApiClient(Dio dio) => ApiClient(dio); // reported

  String _baseUrl() => 'https://example.com'; // ok, a private helper
}
```

Skill: [inject-annotation-create-module][create-module]

### require_valid_module_list

The rule checks the lists in `@Component([...])`, `@Subcomponent([...])`,
`@Module(includes: [...])` and `@Module(subcomponents: [...])`. It reports an
entry that is one of these:

- listed twice in the same list.
- a `@subcomponent` class in a module list. Install a subcomponent with
  `@Module(subcomponents: [...])`.
- a class without `@module` in `includes`.
- a class without `@subcomponent` in `subcomponents`.

```dart
@Component([ApiModule, ApiModule]) // the second ApiModule is reported
abstract class MainComponent {}

@Module(includes: [Logger]) // reported, Logger has no @module
class AppModule {}
```

Skill: [inject-annotation-create-module][create-module]

### require_provision_listener_type

A `@provisionListener` method must return a class that implements
`ProvisionListener`.

```dart
@module
class AppModule {
  @provides
  @provisionListener
  String provideListener() => 'log'; // reported
}
```

Skill: [inject-annotation-create-module][create-module]

### avoid_qualified_and_unqualified_provider

A module that provides the same type with and without a qualifier has usually
lost a qualifier. The rule reports the provider without a qualifier.

```dart
@module
class AppModule {
  @provides
  @baseUrl
  String provideBaseUrl() => 'https://example.com';

  @provides
  String provideApiKey() => 'secret'; // reported
}
```

If you want both bindings, add an `ignore` comment.

Skill: [inject-annotation-create-module][create-module]

### prefer_inject_over_provides

Style rule. A module is for types you cannot annotate, such as third-party
classes. The rule reports a `@provides` method that only forwards its own
parameters to the constructor of a class from the same package. Annotate that
class with `@inject` instead.

```dart
@module
class AuthModule {
  @provides
  @singleton
  AuthRepository provideAuthRepository(BooksApi api, Logger logger) =>
      AuthRepository(api, logger); // reported
}
```

The rule does not report a provider that adds something of its own:

- It passes a module field or a literal to the constructor.
- Its return type is an interface that it binds to an implementation.
- It creates a class from another package.
- It is annotated with `@asynchronous` or `@provisionListener`.

The rule also reports a provider in a subcomponent's module that scopes a
singleton to that subcomponent, because it looks like plain forwarding. Add an
`ignore` comment to such a provider.

Skill: [inject-annotation-create-module][create-module]

### avoid_inline_qualifier

Style rule. Declare a qualifier as a constant. With an inline
`@Qualifier(#name)`, a typo in one place creates a second binding key, and the
compiler does not notice.

```dart
@provides
@Qualifier(#baseUrl) // reported
String provideBaseUrl() => 'https://example.com';

const baseUrl = Qualifier(#baseUrl);

@provides
@baseUrl // ok
String provideBaseUrl() => 'https://example.com';
```

Skill: [inject-annotation-create-module][create-module]

## Injected classes

### require_unambiguous_inject_constructor

inject.dart must know which constructor to call. The rule reports a class
with one of these problems:

- Several `@inject` constructors, or several `@assistedInject` constructors,
  where a constructor has no `@Qualifier`, or two have the same one.
- A qualifier on such a constructor that is no valid identifier, such as
  `#a.b`. The generator builds a class name from it.
- `@inject` on the class, several constructors, and no unnamed one.

```dart
class ApiClient { // reported
  @inject
  ApiClient();

  @inject
  ApiClient.mock();
}
```

Skill: [inject-annotation-setup-di][setup-di]

### avoid_asynchronous_on_inject

`@asynchronous` only works on a `@provides` method. inject.dart ignores it on
an injected class or constructor.

```dart
@inject
@asynchronous // reported
class Database {}
```

Skill: [inject-annotation-create-module][create-module]

## Assisted injection

### require_assisted_parameter

An `@assistedInject` constructor needs at least one `@assisted` parameter,
the value that the caller passes. Without one, use `@inject`.

```dart
class Greeter {
  @assistedInject
  Greeter(Logger logger); // reported
}
```

Skill: [inject-annotation-add-assisted-injection][assisted-injection]

### require_valid_factory

An `@assistedFactory` or `@subcomponentFactory` class must be `abstract` and
have exactly one abstract method.

For an `@assistedFactory`, the method must return a class with an
`@assistedInject` constructor. If the class has several, the method needs the
`@Qualifier` of the one to use. The method's parameters must match the
constructor's `@assisted` parameters: the same number, the same types, and the
same names for named parameters.

For a `@subcomponentFactory`, the method must return a `@subcomponent` class
and may take each module only once.

```dart
class Greeter {
  @assistedInject
  Greeter(Logger logger, {@assisted required String name});
}

@assistedFactory
abstract class GreeterFactory { // reported: 'name' must be a String
  Greeter create({required int name});
}
```

The rule does not check that a subcomponent module without a no-argument
constructor is a parameter of the factory method. The generator reports that.

Skill: [inject-annotation-add-assisted-injection][assisted-injection]

## Flutter widgets

### prefer_injected_widget

Style rule. A public widget that takes a type from the dependency graph should
be created through injection. The rule reports such a widget when neither the
class nor a constructor carries `@assistedInject` or `@inject`.

```dart
class HomePage extends StatelessWidget { // reported
  const HomePage({super.key, required this.viewModelFactory});

  final ViewModelFactory<CounterViewModel> viewModelFactory;
}

class HomePage extends StatelessWidget { // ok
  @assistedInject
  const HomePage({@assisted super.key, required this.viewModelFactory});

  final ViewModelFactory<CounterViewModel> viewModelFactory;
}
```

A parameter type counts as a type from the graph when it is one of these:

- A class that carries `@inject` or `@assistedInject`, or whose constructor
  does.
- A factory: a class annotated with `@assistedFactory` or
  `@subcomponentFactory`, or a generated factory such as `HomePageFactory`.
- `ViewModelFactory<T>` or `Provider<T>`.
- A class annotated with `@Component` or `@Subcomponent`.

A widget that only takes plain values and callbacks has no such parameter, so
the rule never reports a design system widget such as a button.

The rule does not recognize a type that only a `@provides` method binds, such
as a third-party class or an interface.

Skill: [inject-annotation-add-assisted-injection][assisted-injection]

### avoid_manual_view_model_builder

Style rule. Do not construct a `ViewModelBuilder` by hand. Inject a
`ViewModelFactory<T>` and call it. The factory returns the `ViewModelBuilder`
with the view model from the graph.

Skill: [inject-annotation-flutter-view-model][view-model]

## Develop

Each rule lives in `lib/src/rules` and has a test in `test`. The tests run on
stub packages, which `test/support.dart` defines.

```bash
dart test
```

A check mirrors a diagnostic of `inject_generator`. When you change a
diagnostic in the generator, update the matching rule.

[setup-di]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-setup-di/SKILL.md
[create-module]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-create-module/SKILL.md
[assisted-injection]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-add-assisted-injection/SKILL.md
[view-model]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject-annotation-flutter-view-model/SKILL.md
