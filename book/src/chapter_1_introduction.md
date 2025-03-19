# Introduction

Welcome to this guide on compile-time dependency injection for Dart and
Flutter! This book will walk you through the concepts, implementation, and
best practices for using dependency injection effectively in your Dart and
Flutter applications.

## What is Dependency Injection?

[Dependency injection (DI)](https://en.wikipedia.org/wiki/Dependency_injection)
is a design pattern that allows us to write more maintainable, testable,
and modular code. At its core, DI means that instead of a class creating
its own dependencies, those dependencies are passed in (usually through the
constructor). For example, rather than a `UserRepository` creating its own
`DatabaseService`, that service is provided to the repository when it's
created.

This library specifically implements
[constructor injection](https://en.wikipedia.org/wiki/Dependency_injection#Constructor_injection),
where dependencies are provided through class constructors, making the
dependency relationships explicit and easy to understand.

## Why Compile-time?

While many dependency injection frameworks operate at runtime, compile-time
dependency injection offers several significant advantages:

- **Performance**: No runtime overhead since all the wiring happens during
  compilation
- **Code Size**: Your app remains lean without additional runtime overhead,
  and the compiler can optimize the generated code more effectively since
  the dependency graph is known at compile-time
- **Compile-time Validation**: Errors in your dependency graph are caught
  during compilation, not at runtime
- **IDE Support**: Better code navigation and refactoring capabilities

> **Technical note**: For precision, what we call "compile-time dependency
> injection" actually happens during the build process, before final
> compilation. Some might argue "build-time dependency injection" would be
> more accurate. However, "compile-time" is the established term in contrast
> to "runtime" approaches, effectively communicating that dependencies are
> resolved statically rather than dynamically.

## About This Library

This library provides a clean, annotation-based approach to compile-time
dependency injection in Dart and Flutter. It's inspired by
[Dagger](https://dagger.dev/), the popular dependency injection framework
used in Android development. Using simple annotations like `@inject`,
`@provides`, and `@singleton`, you can define your dependency graph in a
way that's both intuitive and powerful.

The library generates code that's nearly identical to what you would write
by hand, ensuring maximum performance and minimal overhead.

## Who This Book Is For

This book is designed for Dart and Flutter developers of all experience
levels:

- If you're new to dependency injection, you'll learn the fundamentals and
  how to apply them
- If you're experienced with DI but new to compile-time approaches, you'll
  see how this technique improves upon runtime DI
- If you're already familiar with compile-time DI in other languages,
  you'll
  learn how to leverage it effectively in Dart

In the following chapters, we'll dive deeper into the components of this
library, explore practical examples, and discover best practices for
organizing dependencies in real-world applications.
