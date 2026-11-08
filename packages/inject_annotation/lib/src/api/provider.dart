/// A lazy provider for a dependency of type [T].
///
/// Inject [Provider] instead of `T` to defer construction to call time or to
/// produce multiple independent instances of a non-singleton.
///
/// A constructor parameter of this type needs a synchronous dependency chain.
/// Over an `@asynchronous` chain it is a build error, because [get] must
/// return `T` synchronously. At an `@inject` constructor, inject `T` directly.
///
/// The generator creates a concrete implementation; users never implement this
/// interface directly.
abstract class Provider<T> {
  /// Returns an instance of [T].
  T get();
}
