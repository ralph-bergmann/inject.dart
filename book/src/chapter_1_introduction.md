# Introduction

inject.dart is a compile-time dependency injection library for Dart and
Flutter. This book explains how it works and how to use it in real
applications, and it includes a reference for every annotation.

## What is dependency injection?

[Dependency injection (DI)](https://en.wikipedia.org/wiki/Dependency_injection)
is a design pattern in which a class gets its collaborators from outside and
does not create them itself. A `CounterRepository`, for example, receives its
`Database` through the constructor. The dependency is *injected*.

inject.dart uses
[constructor injection](https://en.wikipedia.org/wiki/Dependency_injection#Constructor_injection):
every dependency is an explicit constructor parameter. The library has no
hidden registry or `Type → Instance` map, and no global state.

## Why compile-time?

Most DI frameworks resolve the dependency graph at runtime. Your app registers
bindings in a setup block and calls `.get<Foo>()` when it needs something, so
the full graph is known only after the app starts.

inject.dart resolves the graph *before* your app runs, as part of the build. A
missing binding, a dependency cycle, or a qualifier mismatch fails the build.
With a runtime framework, the same mistakes show up as a crash at screen 7, a
stack overflow, or a failed assertion at call time.

The generator emits plain Dart that the compiler optimises like hand-written
code, so there is no runtime overhead and no reflection or `dart:mirrors`.
Refactoring is safer too: rename a class and the analyzer shows every affected
wiring, because nothing depends on magic strings or `Type` lookups.

> What we call "compile-time DI" runs during the build step, before final
> compilation. "Build-time DI" would be more accurate, but "compile-time" is the
> established term for the contrast with runtime approaches.

## How inject.dart compares to get_it and injectable

`get_it` is the most widely used DI solution in the Flutter ecosystem. It is a
runtime service locator: bindings are registered in an imperative setup block
and resolved dynamically via `GetIt.I<Foo>()` calls scattered through app code.
`injectable` generates those registration calls into `get_it`, but the locator
itself and its runtime failure modes remain.

inject.dart generates the entire component implementation from annotations.

| Aspect                            | `get_it` / `injectable`     | inject.dart                          |
|-----------------------------------|-----------------------------|--------------------------------------|
| When bindings are resolved        | runtime                     | build time                           |
| Missing binding                   | crash at first `.get()`     | build error                          |
| Cyclic dependency                 | runtime error               | build error                          |
| Qualifier mismatch                | runtime                     | build error                          |
| Service locator calls in app code | yes (`GetIt.I<Foo>()`)      | none                                 |
| Registration boilerplate          | hand-written or generated   | none: annotate & run `build_runner`  |
| Generated artefact                | registrations into `get_it` | full component implementation        |

The downside of inject.dart is the code generation step. You must run
`dart run build_runner build` whenever annotated code changes, and you have to
manage the generated files (`*.inject.dart`, `*.factory.dart`) or commit them,
as the pub.dev example does. `get_it` needs no code generation and has less to
set up in a trivial app.

Compile-time checks pay off most in larger codebases, where a missing binding
or a refactoring mistake could otherwise stay hidden until it crashes in
production.

## About this library

inject.dart is inspired by [Dagger](https://dagger.dev/), the annotation-based
DI framework used in Android development. The annotation vocabulary
(`@inject`, `@provides`, `@singleton`, `@Component`, `@module`) maps closely to
Dagger's, so the mental model transfers if you have Android experience.

The generator emits code that is nearly identical to what you would write by
hand: immutable component classes with `late final` singleton fields, typed
provider classes, and factory methods. You can read and diff the output like
any other Dart code.

## Who this book is for

If you are new to DI, this book teaches the fundamentals and how to apply them
in Flutter. Readers coming from a runtime DI framework will see how static
analysis at build time changes refactoring and debugging. Dagger and Hilt users
will find that the concepts map directly and can focus on the Dart and Flutter
specifics.

The following chapters build up from installation to a full layered Flutter
app, then cover testing patterns and the complete annotation reference.
