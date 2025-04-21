import 'annotations.dart';

/// Annotates a class that implements [ProvisionListener].
///
/// For a class to function as a provision listener, it must:
/// 1. Be annotated with [provisionListener]
/// 2. Implement the [ProvisionListener<T>] interface, where:
///    - If `T` is specified, the listener will only be called for objects of type `T`
///    - If `T` is omitted (using [ProvisionListener] without a type parameter),
///      the listener will be called for all provisioned objects
/// 3. Be registered in a [Component]'s `provisionListeners` parameter
///
/// When an object is provisioned, the listener's `onProvision` method
/// is called with a [ProvisionInvocation] object containing the provisioned instance.
///
/// Classes with this annotation are automatically injected as [singleton]s.
///
/// To use provision listeners, they must be explicitly added to the [Component]'s
/// `provisionListeners` parameter:
///
/// ```dart
/// @Component(
///   modules: [MyModule],
///   provisionListeners: [LoggingListener, AnalyticsListener]
/// )
/// abstract class MyComponent {
///   // Component methods...
/// }
/// ```
///
/// Example of a type-specific listener:
/// ```dart
/// @provisionListener
/// class LoggingListener implements ProvisionListener<User> {
///   @override
///   void onProvision(ProvisionInvocation<User> provision) {
///     print('About to provision User');
///     final user = provision.provision();
///     print('User provisioned: ${user.name}');
///   }
/// }
/// ```
///
/// Example of a listener for all objects:
/// ```dart
/// @provisionListener
/// class GlobalListener implements ProvisionListener {
///   @override
///   void onProvision(ProvisionInvocation provision) {
///     print('Provisioning object of type: ${provision.type}');
///     final object = provision.provision();
///     print('Object provisioned: $object');
///   }
/// }
/// ```
///
/// [ProvisionListener]s can have their own dependencies that are resolved automatically:
///
/// ```dart
/// @provisionListener
/// class AnalyticsListener implements ProvisionListener<User> {
///   AnalyticsListener(this.analytics);
///
///   final AnalyticsService analytics;
///
///   @override
///   void onProvision(ProvisionInvocation<User> provision) {
///     final user = provision.provision();
///     analytics.trackUserCreated(user);
///   }
/// }
/// ```
const provisionListener = ProvisionListener._();

/// Listens for provisioning of objects in the dependency injection system.
///
/// The [ProvisionListener] interface allows you to intercept and monitor the
/// creation of objects during the dependency injection process. It enables
/// cross-cutting concerns like:
///
/// * Gathering timing information about object creation
/// * Logging or monitoring object provisioning
/// * Post-provision initialization of objects
/// * Validation of created instances
/// * Applying aspects across multiple object types
///
/// ## Type-Specific vs. Global Listening
///
/// The generic type [T] determines which objects this listener will be notified about:
///
/// * [ProvisionListener<User>] - Only notified when `User` objects are provisioned
/// * [ProvisionListener] - Notified for all object provisions
///
/// ## Lifecycle
///
/// 1. When the injector needs to provide an instance of type [T], it first
///    notifies all registered [ProvisionListener]s that match that type
/// 2. Each listener's [onProvision] method is called with a [ProvisionInvocation] object
/// 3. When the listener calls [ProvisionInvocation.provision()], it triggers the actual creation
///    of the object if it hasn't been created yet
/// 4. The object is created only once - the first time [provision()] is called
/// 5. Subsequent calls to [provision()] return the same object reference
/// 6. After all listeners have processed, the object is used for injection
///
/// Note that there is no guaranteed order in which listeners are called.
///
/// ## Example Usage
///
/// ```dart
/// // Interface for disposable resources
/// abstract interface class Disposable {
///   void dispose();
/// }
///
/// // Listener that automatically registers all Disposable objects
/// @provisionListener
/// class DisposableListener implements ProvisionListener<Disposable> {
///   DisposableListener();
///
///   final List<Disposable> _disposables = [];
///
///   @override
///   void onProvision(ProvisionInvocation<Disposable> provision) {
///     final disposable = provision.provision();
///     _disposables.add(disposable);
///   }
///
///   void disposeAll() {
///     for (final disposable in _disposables) {
///       disposable.dispose();
///     }
///     _disposables.clear();
///   }
/// }
/// ```
///
/// In this example, any object that implements `Disposeable` will be automatically
/// registered with the `DisposableListener` when it's created, allowing for centralized
/// resource cleanup.
interface class ProvisionListener<T> {
  const ProvisionListener._();

  /// Called when an object of type [T] is about to be provisioned by the injector.
  ///
  /// This method is invoked before the object has been created. The listener
  /// can control when the object is created by calling [provision.provision()].
  ///
  /// Common patterns include:
  /// * Pre-provision: Do work before calling provision()
  /// * Post-provision: Call provision() and then do work with the result
  /// * Timing: Measure how long provision() takes to execute
  /// * Registration: Register the provisioned object with other systems
  void onProvision(ProvisionInvocation<T> provision) {
    throw UnimplementedError();
  }
}

/// Encapsulates a single act of provisioning.
///
/// This object wraps the provisioning process and allows listeners to
/// control when the actual object creation happens.
abstract interface class ProvisionInvocation<T> {
  /// Creates and returns the provisioned object.
  ///
  /// The first call to this method will trigger the actual creation of the
  /// object. Subsequent calls will return the same instance.
  ///
  /// This allows listeners to:
  /// 1. Perform pre-provisioning work
  /// 2. Call provision() to create/get the instance
  /// 3. Perform post-provisioning work
  T provision();
}
