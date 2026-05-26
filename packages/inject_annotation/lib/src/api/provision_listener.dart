// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A listener that is notified after a dependency instance is provisioned.
///
/// Implement this interface and register it through a module with the
/// `@provisionListener` annotation to receive callbacks after dependency
/// creation.
///
/// Listeners are treated as singletons — a single instance observes all
/// provisions regardless of how many types it monitors.
///
/// Example — catch-all listener (fires for all provisions). Use
/// `ProvisionListener<Object>`; a raw `ProvisionListener` makes [onProvision]
/// take `dynamic`, which an `Object` parameter cannot validly override:
/// ```dart
/// class LoggingListener implements ProvisionListener<Object> {
///   @override
///   void onProvision(Object instance) {
///     print('Provisioned: $instance');
///   }
/// }
///
/// @module
/// class AppModule {
///   @provides
///   @singleton
///   @provisionListener
///   ProvisionListener provideLoggingListener() => LoggingListener();
/// }
/// ```
///
/// Example — type-specific listener (fires only for `Closeable` instances):
/// ```dart
/// class CloseableListener implements ProvisionListener<Closeable> {
///   @override
///   void onProvision(Closeable instance) {
///     _trackCloseable(instance);
///   }
/// }
///
/// @module
/// class AppModule {
///   @provides
///   @singleton
///   @provisionListener
///   ProvisionListener<Closeable> provideCloseableListener() =>
///       CloseableListener();
/// }
/// ```
abstract class ProvisionListener<T> {
  /// Called after a dependency instance has been provisioned.
  ///
  /// The [instance] is the newly created dependency object.
  /// Exceptions from this method propagate unhandled to the caller.
  void onProvision(T instance);
}
