# Introduction

Welcome to the inject.dart documentation — compile-time dependency injection
for Dart and Flutter. This book walks you through the concepts, annotation
reference, and best practices for using inject.dart in real applications.

## What is Dependency Injection?

[Dependency injection (DI)](https://en.wikipedia.org/wiki/Dependency_injection)
is a design pattern where a class receives its collaborators from the outside
rather than creating them itself. Instead of a `CounterRepository` constructing
its own `Database`, the database is passed in through the constructor. The
dependency is *injected*.

This library implements
[constructor injection](https://en.wikipedia.org/wiki/Dependency_injection#Constructor_injection):
every dependency is an explicit constructor parameter. There is no hidden
registry, no `Type → Instance` map, and no global state.

## Why Compile-time?

Most DI frameworks resolve the dependency graph at runtime — your app registers
bindings in a setup block and calls `.get<Foo>()` when it needs something. The
graph is only fully known after the app starts.

inject.dart resolves the graph *before* your app runs, as part of the build:

- **Missing bindings** produce a build error, not a crash at screen 7.
- **Cyclic dependencies** are detected statically, not by a stack overflow.
- **Qualifier mismatches** fail the build, not an assertion at call time.
- **Zero runtime overhead**: the generator emits plain Dart that the compiler
  optimises like hand-written code. No reflection, no `dart:mirrors`.
- **Refactor-safe**: rename a class and the analyzer shows every affected
  wiring. No magic strings, no `Type` lookups.

> For precision: what we call "compile-time DI" actually runs during the build
> step, before final compilation. "Build-time DI" would be technically more
> accurate, but "compile-time" is the established term contrasting with runtime
> approaches.

## How inject.dart Compares to get_it and injectable

`get_it` is the most widely used DI solution in the Flutter ecosystem. It is a
runtime service locator: bindings are registered in an imperative setup block
and resolved dynamically via `GetIt.I<Foo>()` calls scattered through app code.
`injectable` generates those registration calls into `get_it`, but the locator
itself and its runtime failure modes remain.

inject.dart takes a different approach — generating the **entire** component
implementation from annotations. The comparison is honest:

| Aspect                            | `get_it` / `injectable`     | inject.dart                          |
|-----------------------------------|-----------------------------|--------------------------------------|
| When bindings are resolved        | runtime                     | build time                           |
| Missing binding                   | crash at first `.get()`     | build error                          |
| Cyclic dependency                 | runtime error               | build error                          |
| Qualifier mismatch                | runtime                     | build error                          |
| Service locator calls in app code | yes (`GetIt.I<Foo>()`)      | none                                 |
| Registration boilerplate          | hand-written or generated   | none — annotate & run `build_runner` |
| Generated artefact                | registrations into `get_it` | full component implementation        |

**Honest cons of inject.dart:** there is a codegen step — you run
`dart run build_runner build` whenever annotated code changes, and generated
files (`*.inject.dart`, `*.factory.dart`) need to be managed (or committed, in
the case of the pub.dev example). `get_it` has zero codegen and a smaller
initial surface area for trivial apps.

The compile-time value proposition matters most in larger codebases where a
missing binding or a refactoring mistake would otherwise be invisible until it
crashes in production.

## About This Library

inject.dart is inspired by [Dagger](https://dagger.dev/), the annotation-based
DI framework used in Android development. The annotation vocabulary
(`@inject`, `@provides`, `@singleton`, `@Component`, `@module`) maps closely to
Dagger's, so the mental model transfers if you have Android experience.

The generator emits code that is nearly identical to what you would write by
hand: immutable component classes with `late final` singleton fields, typed
provider classes, and factory methods. The output is readable, diffable Dart —
not a black box.

## Who This Book Is For

- **New to DI:** learn the fundamentals and how to apply them in Flutter.
- **Runtime DI → compile-time:** see why static analysis at build time changes
  the refactoring and debugging experience.
- **Dagger / Hilt background:** the concepts map directly; this book focuses on
  the Dart/Flutter-specific parts.

In the following chapters we build up from installation to a full layered
Flutter app, then cover testing patterns and the complete annotation reference.
