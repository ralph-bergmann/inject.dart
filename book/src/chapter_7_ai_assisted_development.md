# AI Coding Assistants

Most developers now build with an AI coding assistant, so inject.dart ships
first-class guidance for them. Your assistant gets the annotations, the
`build_runner` workflow, and the compile-time DI model right — without you
re-explaining it every session. There are two complementary channels: a rules
document and installable Agent Skills.

## AI rules file

## Agent Skills

For agents that support the [Agent Skills][agentskills] format (Claude Code and
others), inject.dart provides task-focused skills under [`skills/`][skills-dir].
Where the rules file is one big document, each skill teaches *how* to perform a
single concrete task and is activated only when relevant. Install them with
either tool:

```shell
# Node tool — installs straight from the GitHub repo
npx skills add https://github.com/ralph-bergmann/inject.dart/tree/master/packages/inject_annotation/skills --skill '*' --agent universal

# Dart tool (https://pub.dev/packages/skills) — discovers skills from your
# dependency tree and configured GitHub registries, into your IDE's skills dir
dart pub global activate skills
skills get
```

| Skill                                                        | Use it to…                                                                                                        |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| [`inject_annotation-setup-di`][skill-setup]                  | Add `build_runner` + inject.dart and scaffold the root component (from scratch).                                  |
| [`inject_annotation-add-injectable`][skill-injectable]       | Make a class injectable with `@inject` and expose it; `@singleton`.                                               |
| [`inject_annotation-create-module`][skill-module]            | Provide third-party / configured types with a `@module` (`@provides`, `@asynchronous`, `Qualifier`).              |
| [`inject_annotation-add-assisted-injection`][skill-assisted] | Mix injected and runtime parameters with `@assistedInject` / `@assisted` / `@assistedFactory`.                    |
| [`inject_annotation-inject-provider`][skill-provider]        | Inject `Provider<T>` for lazy or multiple instances.                                                              |
| [`inject_annotation-add-provision-listener`][skill-listener] | Observe provisioning with `ProvisionListener<T>` + `@provisionListener`.                                          |
| [`inject_annotation-flutter-view-model`][skill-viewmodel]    | Bind a `ChangeNotifier` view model to a widget with `ViewModelFactory` / `ViewModelBuilder` (sync or async init). |
| [`inject_annotation-write-tests`][skill-tests]               | Test injected code with a test component + test module + fakes.                                                   |

Together they cover every annotation in `inject_annotation` (`@component`,
`@module`, `@inject`, `@provides`, `@singleton`, `@asynchronous`, `Qualifier`,
`@assistedInject` / `@assisted` / `@assistedFactory`, `@provisionListener`), the
runtime contracts `Provider<T>` and `ProvisionListener<T>`, and the
`inject_flutter` view-model API.

## The core rule

Whichever channel you use, the one rule that anchors all the guidance is:
inject.dart is **constructor injection only** — "if it builds, it runs." A good
assistant never suggests service-locator patterns (`get_it`, `provider` used as
a locator, or hand-rolled registries), and re-runs code generation after every
annotation change:

```shell
dart run build_runner build --delete-conflicting-outputs
```

## Validating the skills

The skills must stay true to the generator's *actual* behaviour, not assumptions
about it. The strongest check — for example after the generator changes — is to
**run each skill**: have your AI assistant carry out the task each skill teaches,
then prove the result compiles and generates correctly.

1. Create a temporary pure-Dart package `_scratch/` — a `pubspec.yaml` with
   `resolution: workspace`, `inject_annotation` as a dependency, and
   `build_runner` + `inject_generator` (plus `test` if you exercise the testing
   skill) as dev-dependencies.
2. Add `_scratch` to the `workspace:` list in the root `pubspec.yaml`.
3. Inside `_scratch/`, **follow each skill to perform its task** — execute the
   skill as a user would, rather than copying snippets out of it:
   `inject_annotation-setup-di` to scaffold the component, `inject_annotation-add-injectable`
   for a service, `inject_annotation-create-module` to provide a configured /
   `@asynchronous` / `Qualifier`-ed type, then
   `inject_annotation-add-assisted-injection`, `inject_annotation-inject-provider`,
   `inject_annotation-add-provision-listener`, and `inject_annotation-write-tests`. The
   Flutter-only `inject_annotation-flutter-view-model` is exercised in a Flutter package
   — `examples/flutter_demo` already runs it and stays green.
4. Run `dart pub get`, then inside `_scratch/`: `dart run build_runner build`
   and `dart analyze`.
5. Confirm the build writes outputs and `dart analyze` reports **No issues
   found!** — i.e. following the skills produced code that **compiles** and
   generates correctly. Skim the generated `*.inject.dart` to confirm the wiring
   matches what each skill claims.
6. Delete `_scratch/` and revert the `pubspec.yaml` edit.

A prompt you can hand your AI tool verbatim:

> With the inject.dart skills installed, create a temporary pure-Dart workspace
> member `_scratch/` and **follow each skill to carry out its task** (set up DI,
> add an injectable, create a module, assisted injection, inject a `Provider`,
> add a provision listener, write a test) — don't copy code out of the skills,
> run them. Add `_scratch` to the root `pubspec.yaml` `workspace:` list, run
> `dart pub get`, then `dart run build_runner build` and `dart analyze` inside
> it. Confirm the build writes outputs, `dart analyze` reports "No issues
> found!", and the generated code compiles and matches what each skill describes.
> Show me the output, then remove `_scratch/` and revert the `pubspec.yaml`.
> (Validate the Flutter view-model skill against `examples/flutter_demo`.)

This is how the skills were validated in the first place: run each one for real,
read the generated output and analyzer result, and document only what the
generator actually does.

[agentskills]: https://agentskills.io/specification
[skills-dir]: https://github.com/ralph-bergmann/inject.dart/tree/master/packages/inject_annotation/skills
[skill-setup]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-setup-di/SKILL.md
[skill-injectable]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-add-injectable/SKILL.md
[skill-module]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-create-module/SKILL.md
[skill-assisted]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-add-assisted-injection/SKILL.md
[skill-provider]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-inject-provider/SKILL.md
[skill-listener]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-add-provision-listener/SKILL.md
[skill-viewmodel]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-flutter-view-model/SKILL.md
[skill-tests]: https://github.com/ralph-bergmann/inject.dart/blob/master/packages/inject_annotation/skills/inject_annotation-write-tests/SKILL.md
