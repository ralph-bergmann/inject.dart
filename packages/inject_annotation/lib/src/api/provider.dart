/// A lazy provider for a dependency of type [T].
///
/// Inject [Provider] instead of `T` to defer construction to call time or to
/// produce multiple independent instances of a non-singleton.
///
/// The generator creates a concrete implementation; users never implement this
/// interface directly.
abstract class Provider<T> {
  /// Returns an instance of [T].
  T get();
}
