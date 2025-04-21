// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
part of '../graph.dart';

const _iterableEquality = IterableEquality<InjectedType>();

/// A provider defined on an `@Component` class.
@immutable
class ComponentProvider {
  /// The type this provides.
  final InjectedType injectedType;

  /// The name of the method or getter to `@override`.
  final String methodName;

  /// Whether this provider is a getter.
  final bool isGetter;

  const ComponentProvider._(this.injectedType, this.methodName, this.isGetter);
}

/// A dependency resolved to a concrete provider.
sealed class ResolvedDependency {
  /// The type this provides.
  final InjectedType injectedType;

  /// Transitive dependencies.
  final Iterable<InjectedType> dependencies;

  const ResolvedDependency(
    this.injectedType,
    this.dependencies,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedDependency &&
          runtimeType == other.runtimeType &&
          injectedType == other.injectedType &&
          _iterableEquality.equals(dependencies, other.dependencies);

  @override
  int get hashCode => injectedType.hashCode ^ _iterableEquality.hash(dependencies);
}

/// A dependency provided by a module class.
@immutable
class DependencyProvidedByModule extends ResolvedDependency {
  /// Module that provides the dependency.
  final SymbolPath moduleClass;

  /// Name of the method in the class.
  final String methodName;

  const DependencyProvidedByModule(
    super.injectedType,
    super.dependencies,
    this.moduleClass,
    this.methodName,
  );
}

/// A dependency provided by an injectable class.
@immutable
class DependencyProvidedByInjectable extends ResolvedDependency {
  const DependencyProvidedByInjectable(
    super.injectedType,
    super.dependencies,
  );
}

/// A dependency provided by an factory class.
@immutable
class DependencyProvidedByFactory extends ResolvedDependency {
  /// Factory that provides the dependency.
  final SymbolPath factoryClass;

  /// Name of the method in the class.
  final String methodName;

  /// Type this factory creates.
  final ProviderSummary createdType;

  /// Manually injected parameters to create an instance of [createdType].
  /// These are the @assisted-annotated constructor parameters of [createdType].
  final List<InjectedType> factoryParameters;

  const DependencyProvidedByFactory(
    super.injectedType,
    super.dependencies,
    this.factoryClass,
    this.methodName,
    this.createdType,
    this.factoryParameters,
  );
}

/// A view model provided by a `ViewModelFactory<T>`.
@immutable
class DependencyProvidedByViewModel extends ResolvedDependency {
  /// The name of the field in which the view model is injected.
  final String methodName;

  /// Type of the view model (the type parameter of `ViewModelFactory<T>`).
  final LookupKey createdType;

  const DependencyProvidedByViewModel(
    super.injectedType,
    super.dependencies,
    this.methodName,
    this.createdType,
  );
}

/// All of the data that is needed to generate an `@Component` class.
class ComponentGraph {
  /// Modules used by the component.
  final Iterable<ModuleSummary> includeModules;

  /// Providers that should be generated.
  final Iterable<ComponentProvider> providers;

  /// Dependencies resolved to concrete providers mapped from key.
  final Map<LookupKey, ResolvedDependency> mergedDependencies;

  /// All provision listeners that were found.
  final Iterable<ProvisionListenerSummary> provisionListeners;

  ComponentGraph._(
    this.includeModules,
    this.providers,
    this.mergedDependencies,
    this.provisionListeners,
  );
}
