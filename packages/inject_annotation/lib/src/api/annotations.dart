// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

import 'provision_listener.dart';

/// Annotates an abstract class used as a blueprint to generate a component.
///
/// Example:
/// ```dart
/// import 'coffee_shop.inject.dart' as g;
///
/// @Component([DripCoffeeModule])
/// abstract class CoffeeShop {
///   static const create = g.CoffeeShop$Component.create;
///
///   CoffeeMaker get coffeeMaker;
/// }
///
/// void main() {
///   final coffeeShop = CoffeeShop.create();
///   print(coffeeShop.coffeeMaker.brewCoffee());
/// }
/// ```
///
/// The example defines a `CoffeeShop` component that provides a `CoffeeMaker`.
/// `DripCoffeeModule` supplies the dependency providers for the component.
///
/// The framework generates `CoffeeShop$Component` with a **synchronous** static
/// `create` factory. Asynchronous resolution does not change `create`; instead a
/// getter whose dependency chain is `@asynchronous` is exposed as `Future<T>`
/// (or `Provider<T>`) and awaited at that entry point.
///
/// `CoffeeShop` declares `static const create` as a convenience accessor to
/// `CoffeeShop$Component.create` — not strictly necessary, but useful to
/// keep generated names out of call sites.
class Component {
  const factory Component([List<Type> modules]) = Component._;

  const Component._([this.modules = const <Type>[]]);

  /// Modules supplying providers for the component.
  ///
  /// Each [Type] must be a `class` definition annotated with [module].
  ///
  /// **Order matters:** later modules override earlier ones for shared
  /// provider keys (same type + same qualifier). See README "Module Override
  /// Semantics" for the test-mock-injection pattern.
  final List<Type> modules;
}

/// Convenience [Subcomponent] annotation with no included modules.
const subcomponent = Subcomponent();

/// Annotates an abstract class used as a blueprint to generate a subcomponent.
///
/// A subcomponent is an encapsulated child graph of a parent [Component]: it
/// can read every binding of its parent, but its own bindings stay invisible
/// to the parent. Use it to hide implementation details (for example an HTTP
/// client that must only be reachable through a public service) or to create
/// object graphs with a shorter lifetime than the parent component (for
/// example a session graph created after login).
///
/// Unlike a [Component], a subcomponent is never listed on the parent
/// directly. It is installed through a module's [Module.subcomponents]
/// parameter, so installing the module is the single integration point:
///
/// ```dart
/// @Subcomponent([HttpModule])
/// abstract class HttpSubcomponent {
///   RestApiService get apiService;
/// }
///
/// @Module(subcomponents: [HttpSubcomponent])
/// class NetworkModule {}
///
/// @Component([NetworkModule])
/// abstract class AppComponent {
///   @inject
///   HttpSubcomponentFactory get httpFactory;
/// }
/// ```
///
/// Installing `NetworkModule` into a component makes the generated
/// `HttpSubcomponentFactory` available as a binding in the parent graph —
/// inject it anywhere, or expose it as an entry point as `AppComponent`
/// does above. Every call to its `create(...)` method produces a fresh
/// subcomponent instance; `@singleton` bindings declared inside the
/// subcomponent live once per subcomponent instance.
///
/// A subcomponent must not re-declare a binding key its parent already
/// provides — that fails the build; it is not an override. In particular,
/// re-exporting one child binding through a parent module provider
/// requires the child to bind it under a different key (typically with a
/// [Qualifier]), with the parent provider binding the plain type.
class Subcomponent {
  const factory Subcomponent([List<Type> modules]) = Subcomponent._;

  const Subcomponent._([this.modules = const <Type>[]]);

  /// Modules supplying providers for the subcomponent.
  ///
  /// Each [Type] must be a `class` definition annotated with [module].
  ///
  /// **Order matters:** later modules override earlier ones for shared
  /// provider keys (same type + same qualifier), exactly like
  /// [Component.modules].
  final List<Type> modules;
}

/// Convenience [Component] annotation with no included modules.
const component = Component();

/// Annotates an abstract class that serves as an explicit factory for a
/// [Subcomponent], replacing the synthesized `<Name>Factory`.
///
/// - The annotated class must be abstract, with exactly one abstract method.
/// - That method's return type must be an installed [Subcomponent] type.
/// - Parameters whose type is one of the subcomponent's own [Module]s are
///   passed through exactly like the synthesized factory's module parameters.
/// - Every other parameter is a **value parameter**: it becomes an instance
///   binding in the subcomponent graph, injectable by any binding declared
///   inside it — the equivalent of Dagger's `@BindsInstance` / Metro's
///   `@Provides` factory parameters. Honors `@Qualifier` and nullability
///   exactly like an ordinary binding.
///
/// Example:
/// ```dart
/// @Subcomponent([ApiModule])
/// abstract class ApiSubcomponent {
///   RestApiService get apiService;
/// }
///
/// @subcomponentFactory
/// abstract class ApiSubcomponentFactory {
///   ApiSubcomponent create(String userId);
/// }
///
/// @Module(subcomponents: [ApiSubcomponent])
/// class NetworkModule {}
/// ```
///
/// Installing `NetworkModule` makes `ApiSubcomponentFactory` a binding in
/// the parent graph. Each `create(userId)` call builds a fresh
/// `ApiSubcomponent` in which `userId` is injectable as an ordinary
/// `String` binding.
const subcomponentFactory = SubcomponentFactory._();

class SubcomponentFactory {
  const SubcomponentFactory._();
}

/// Annotates a class as a collection of providers for dependency injection.
///
/// A class annotated with [module] is a class that can be used to insert
/// dependencies into the object graph. Modules may extend or mixin other
/// modules, or rely on composition to fill in dependencies. Methods can have
/// parameters that are in the object graph and will be invoked with the objects
/// created from the [Component] the module is installed on.
///
/// Example:
/// ```dart
/// @module
/// class CarModule {
///   @provides
///   Car provideCar(Manufacturer manufacturer) =>
///       Car(manufacturer: manufacturer, year: 2019);
/// }
/// ```
///
/// A component that includes `CarModule` knows how to provide an instance of
/// `Car`, given that all parameters of `provideCar` are satisfied in the object graph.
const module = Module._();

class Module {
  const factory Module({List<Type> subcomponents, List<Type> includes}) = Module._;

  const Module._({this.subcomponents = const <Type>[], this.includes = const <Type>[]});

  /// Subcomponents installed by this module.
  ///
  /// Each [Type] must be an `abstract class` annotated with [subcomponent].
  /// Installing this module into a component makes the generated
  /// `<Name>Factory` of every listed subcomponent available as a binding in
  /// that component's graph. See [Subcomponent] for the full pattern.
  final List<Type> subcomponents;

  /// Other `@module` classes whose providers are folded into this module.
  ///
  /// Listing a module on a [Component]/[Subcomponent] pulls in every module
  /// it `includes`, transitively — as if every included module had been
  /// listed directly. This is meant for library authors who want to ship one
  /// public "umbrella" module backed by several internal modules, so a
  /// consuming app only has to list the umbrella module:
  ///
  /// ```dart
  /// @module
  /// class ApiModule { ... }
  ///
  /// @module
  /// class DbModule { ... }
  ///
  /// @Module(includes: [ApiModule, DbModule])
  /// class UmbrellaModule {}
  ///
  /// @Component([UmbrellaModule])
  /// abstract class AppComponent { ... }
  /// ```
  ///
  /// Each [Type] must be a class annotated with [module]. A module reachable
  /// through more than one include path is installed exactly once. A cycle
  /// (a module that transitively includes itself) is a compile-time error.
  ///
  /// **Order matters** among sibling entries, exactly like [Component.modules]:
  /// later entries override earlier ones for shared provider keys. A
  /// component's (or subcomponent's) own directly-listed modules always take
  /// precedence over anything pulled in through `includes`.
  final List<Type> includes;
}

/// Annotation for a method (in a [Component]), class, or
/// constructor that provides an instance.
///
/// - If the annotation is on a class or constructor, the class is entered into
///   the dependency graph and its constructor's arguments are injected when the
///   class is injected.
/// - If the annotation is on a [Component], this indicates that the component
///   should provide instances of the type when the method is called.
///
/// The type provided by this annotation can be further specified by including a
/// [Qualifier] annotation.
const inject = Inject._();

class Inject {
  const Inject._();
}

/// Annotates a class or the constructor of a class that will be created via
/// assisted injection.
const assistedInject = AssistedInject._();

class AssistedInject {
  const AssistedInject._();
}

/// Annotates a parameter for an assisted injection constructor.
///
/// The assisted injection is a dependency injection (DI) pattern used to
/// construct an object where the DI framework can provide some parameters
/// while the user must pass others at build time (also known as assisted).
///
/// A factory is usually responsible for combining all the parameters
/// and creating the object.
const assisted = Assisted._();

class Assisted {
  const Assisted._();
}

/// Annotates an abstract class that serves as a factory for [AssistedInject]-annotated types.
///
/// - The annotated class must be abstract.
/// - Its `create` method's return type must exactly match the [AssistedInject]-annotated type.
/// - Its `create` method's parameters must match the [Assisted]-annotated parameters
///   of the [AssistedInject] constructor.
const assistedFactory = AssistedFactory._();

class AssistedFactory {
  const AssistedFactory._();
}

/// Annotation for a method in a [module].
///
/// The return type is entered into the dependency graph. The method is
/// executed with injected arguments when the return type is requested.
///
/// The type provided by this annotation can be further specified by including a
/// [Qualifier] annotation.
const provides = Provides._();

class Provides {
  const Provides._();
}

/// A named qualifier used alongside [provides] to distinguish bindings of the same type.
///
/// [Qualifier] must be placed at the same level as the `@provides` annotation. It
/// is **illegal** to have more than one [Qualifier] for a given provider.
///
/// Example:
/// ```dart
/// const baseUri = Qualifier(#baseUri);
///
/// @module
/// abstract class RpcModule {
///   @provides
///   @baseUri
///   String provideBaseUri() => 'https://foo.bar/service/v2';
/// }
/// ```
///
/// The symbol `#baseUri` and `String` together form the key in the dependency graph.
class Qualifier {
  /// Create a named provider qualifier from [name].
  @literal
  const factory Qualifier(Symbol name) = Qualifier._;

  const Qualifier._(this.name);

  /// Unique name of the identifier.
  final Symbol name;
}

/// An injectable class or module provider that provides a single instance.
///
/// A dependency annotated with [singleton] is instantiated only once. The
/// same instance satisfies all dependencies.
///
/// Example:
/// ```dart
/// import 'foo_maker.inject.dart' as g;
///
/// @inject
/// @singleton
/// class Foo {}
///
/// @component
/// abstract class FooMaker {
///   static const create = g.FooMaker$Component.create;
///
///   // identical(getFoo(), getFoo()) is guaranteed to be true.
///   Foo getFoo();
/// }
/// ```
const singleton = Singleton._();

class Singleton {
  const Singleton._();
}

/// Annotates a module provider method that returns a `Future`.
///
/// Such a provider is referred to as _asynchronous provider_. Asynchronous
/// providers are resolved from futures into dependency instances prior to
/// returning the component to the application.
///
/// For example:
/// ```dart
/// @module
/// abstract class CarModule {
///   @provides
///   @asynchronous
///   Future<Car> provideCar();
/// }
///
/// class Dealership {
///   @inject
///   Dealership(Car car);
/// }
/// ```
///
/// Note that in the example `Dealership` depends on `Car` rather than
/// `Future<Car>`. This is the quintessential property of the [asynchronous]
/// annotation. It guarantees that `Future<Car>` is resolved into `Car`
/// _prior to_ instantiating objects that depend on it.
///
/// If you wish to inject the `Future` itself without resolving it, simply
/// omit this annotation and the `Future` will be treated as a normal type, and
/// the framework will not attempt to resolve it.
///
/// For example:
/// ```dart
/// @module
/// abstract class CarModule {
///   @provides
///   Future<Car> provideCar();
/// }
///
/// class Dealership {
///   @inject
///   Dealership(Future<Car> car);
/// }
/// ```
const asynchronous = Asynchronous._();

class Asynchronous {
  const Asynchronous._();
}

/// Annotates a `@provides` method in a `@module` to indicate that the
/// returned value is a [ProvisionListener].
///
/// The listener will be invoked after each dependency provisioning.
/// ProvisionListeners should typically also be annotated with `@singleton`
/// as they are reused across all provisions.
///
/// Example:
/// ```dart
/// @module
/// class AppModule {
///   @provides
///   @singleton
///   @provisionListener
///   ProvisionListener provideListener() => MyListener();
/// }
/// ```
const provisionListener = ProvisionListenerAnnotation._();

class ProvisionListenerAnnotation {
  const ProvisionListenerAnnotation._();
}
