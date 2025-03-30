// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

/// Annotates an abstract class used as a blueprint to generate an [Component].
///
/// Example:
///     import 'coffee_shop.inject.dart';
///
///     @Component(const [DripCoffeeModule])
///     abstract class CoffeeShop {
///       static final create = CoffeeShop$Component.create;
///
///       CoffeeMaker get coffeeMaker;
///     }
///
///     main() async {
///       var coffeeShop = await CoffeeShop.create(new DripCoffeeModule());
///       print(coffeeShop.coffeeMaker.brewCoffee());
///     }
///
/// In the example, we define an component class `CoffeeShop`, which provides a
/// `CoffeeMaker`. It uses `DripCoffeeModule` as a source of dependency
/// providers for the component.
///
/// The framework generates a concrete class `CoffeeShop$Component` that has a
/// static asynchronous function named `create`, which takes `DripCoffeeModule`
/// as an argument and returns a `Future<CoffeeShop>`.
///
/// `CoffeeShop` defines `static final create` as a convenience accessor to
/// `CoffeeShop$Component.create`. This is not strictly necessary, but useful to
/// hide the generated code from the call sites.
class Component {
  /// Modules supplying providers for the component.
  ///
  /// Each [Type] must be a `class` definition annotated with [module].
  final List<Type> modules;

  // ignore: public_member_api_docs
  const factory Component([List<Type> modules]) = Component._;

  const Component._([this.modules = const <Type>[]]);
}

/// An annotation to mark something as an [Component] with no included modules.
const component = Component();

/// Annotates a class as a collection of providers for dependency injection.
///
/// A class annotated with [module] is a class that can be used to insert
/// dependencies into the object graph. Modules may extend or mixin other
/// modules, or rely on composition to fill in dependencies. Methods can have
/// parameters that are in the object graph and will be invoked with the objects
/// created from the [Component] the module is installed on.
///
/// An example:
///
///     @module
///     class CarModule {
///       @provides
///       Car provideCar(Manufacturer manufacturer) =>
///           Car(manufacturer: manufacturer, year: 2019);
///     }
///
/// In this instance, an component that includes `CarModule` will know how to
/// provide an instance of `Car`, given that all parameters of `provideCar` are
/// satisfied in the final object graph.
const module = Module._();

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
class Module {
  const Module._();
}

/// Annotation for a method (in an [Component]), class, or
/// constructor that provides an instance.
///
/// - If the annotation is on a class or constructor, the class is entered into
///   the dependency graph and its constructor's arguments are injected when the
///   class is injected.
/// - If the annotation is on an [Component], this indicates that the component
///   should provide instances of the type when the method is called.
///
/// The type provided by this annotation can be further specified by including a
/// [Qualifier] annotation.
const inject = Inject._();

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
class Inject {
  const Inject._();
}

/// Annotates a class or the constructor of a class that will be created via
/// assisted injection.
const assistedInject = AssistedInject._();

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
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

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
class Assisted {
  const Assisted._();
}

/// Annotates an abstract class used to create an instance of a type via an
/// [AssistedInject] constructor.
///
/// - The type must be an abstract class.
/// - Return type must exactly match the type of the [AssistedInject] type
/// - Parameters must match the exact list of [Assisted] parameters in the
///   [AssistedInject] type's constructor
const assistedFactory = AssistedFactory._();

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
class AssistedFactory {
  const AssistedFactory._();
}

/// Annotation for a method (in an [module]).
///
/// The return type is entered into the dependency graph. The method will be
/// executed with injected arguments when the return type is injected.
///
/// The type provided by this annotation can be further specified by including a
/// [Qualifier] annotation.
const provides = Provides._();

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
class Provides {
  const Provides._();
}

/// A reserved name that can be used alongside a [provides] annotation to further
/// specify the key.
///
/// [Qualifier] must be placed at the same level as a `@provides` annotation. It
/// is **illegal** to have more than one [Qualifier] for a given provider.
///
/// # Example
///     const baseUri = const Qualifier(#baseUri);
///
///     abstract class RpcModule {
///       @provides
///       @baseUri
///       String provideBaseUri() => 'https://foo.bar/service/v2';
///     }
///
/// The symbol `#baseUri` AND `String` are used to form the key in the
/// dependency tree.
class Qualifier {
  /// Unique name of the identifier.
  final Symbol name;

  /// Create a named provider qualifier from [name].
  @literal
  const factory Qualifier(Symbol name) = Qualifier._;

  const Qualifier._(this.name);
}

/// An injectable class or module provider that provides a single instance.
///
/// A dependency annotated with [singleton] will only be instantiated once. The
/// same instance will be used to satisfy all dependencies.
///
/// For example:
///     @inject
///     @singleton
///     class Foo {}
///
///     @component
///     abstract class FooMaker {
///       static final create = FooMaker$Component.create;
///
///       // identical(getFoo(), getFoo()) is guaranteed to be true.
///       Foo getFoo();
///     }
const singleton = Singleton._();

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
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

/// **INTERNAL ONLY**: Might be exposed if we add flags or other properties.
@visibleForTesting
class Asynchronous {
  const Asynchronous._();
}
