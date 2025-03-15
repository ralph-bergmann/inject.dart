// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
part of '../graph.dart';

/// Assists code generation by doing compile-time analysis of an `@Component`.
///
/// To use, create an [ComponentGraphResolver] for a `@Component`-annotated class:
///     var resolver = ComponentGraphResolver(summaryReader, componentSummary);
///     var graph = await resolver.resolve();
class ComponentGraphResolver {
  final ComponentSummary _componentSummary;
  final List<SymbolPath> _modules = <SymbolPath>[];
  final List<ProviderSummary> _providers = <ProviderSummary>[];
  final SummaryReader _reader;

  /// To prevent rereading the same summaries, we cache them here.
  final Map<SymbolPath, LibrarySummary> _summaryCache = <SymbolPath, LibrarySummary>{};

  /// Create a new resolver that uses a [SummaryReader].
  ComponentGraphResolver(this._reader, this._componentSummary) {
    _componentSummary.modules.forEach(_modules.add);
    _componentSummary.providers.forEach(_providers.add);
  }

  Future<LibrarySummary> _readFromPath(
    SymbolPath p, {
    required SymbolPath requestedBy,
  }) async {
    final cachedSummary = _summaryCache[p];
    if (cachedSummary != null) {
      return cachedSummary;
    }

    final package = p.package!;
    final filePath = path.withoutExtension(p.path!) + summaryOutputExtension;
    try {
      return _summaryCache[p] = await _reader.read(package, filePath);
    } on AssetNotFoundException {
      _logUnresolvedDependency(
        componentSummary: _componentSummary,
        dependency: p,
        requestedBy: requestedBy,
      );
    } on PackageNotFoundException {
      _logUnresolvedDependency(
        componentSummary: _componentSummary,
        dependency: p,
        requestedBy: requestedBy,
      );
    } on InvalidInputException {
      _logUnresolvedDependency(
        componentSummary: _componentSummary,
        dependency: p,
        requestedBy: requestedBy,
      );
    } on FileSystemException {
      _logUnresolvedDependency(
        componentSummary: _componentSummary,
        dependency: p,
        requestedBy: requestedBy,
      );
    } catch (error, stackTrace) {
      builderContext.rawLogger.severe(
        'Unrecognized error trying to find a dependency. '
        'Please file a bug with package:inject.',
        error,
        stackTrace,
      );
    }
    return LibrarySummary(p.toAbsoluteUri());
  }

  /// Return a resolved graph that can be used to generate a `$Component` class.
  Future<ComponentGraph> resolve() async {
    // For every module, load the corresponding library summary that should have
    // already been built in the dependency tree. We then lookup the specific
    // module summary from the library summary.
    final modulesToLoad = _modules.map<Future<ModuleSummary?>>((module) async {
      final moduleSummaries = (await _readFromPath(module, requestedBy: _componentSummary.clazz)).modules;

      final first = moduleSummaries.firstWhereOrNull(
        (s) => s.clazz == module,
      );

      if (first == null) {
        builderContext.rawLogger.severe(
          'Failed to locate summary for module ${module.toAbsoluteUri()} ',
          'specified in component ${_componentSummary.clazz.symbol}.',
        );
      }
      return first;
    });
    final allModules = (await Future.wait<ModuleSummary?>(modulesToLoad)).whereNotNull().toList();

    final providersByModules = <LookupKey, DependencyProvidedByModule>{};

    // We compute the providers by modules in two passes. The first pass finds
    // all keys that are explicitly provided.
    for (final module in allModules) {
      for (final provider in module.providers) {
        final lookupKey = provider.injectedType.lookupKey;
        providersByModules[lookupKey] = DependencyProvidedByModule._(
          provider.injectedType,
          provider.dependencies,
          module.clazz,
          provider.name,
        );
      }
    }

    final providersByInjectables = <LookupKey, DependencyProvidedByInjectable>{};
    final providersByFactory = <LookupKey, DependencyProvidedByFactory>{};

    Future<void> addInjectableIfExists(
      LookupKey key, {
      required SymbolPath requestedBy,
    }) async {
      final isSeen = providersByModules.containsKey(key) ||
          providersByFactory.containsKey(key) ||
          providersByInjectables.containsKey(key);
      if (isSeen) {
        return;
      }

      if (!key.root.isGlobal) {
        final lib = await _readFromPath(key.root, requestedBy: requestedBy);

        for (final injectable in lib.injectables.where((injectable) => injectable.clazz == key.root)) {
          providersByInjectables[key] = DependencyProvidedByInjectable._(
            injectable.constructor.injectedType,
            injectable.constructor.dependencies,
          );
          for (final dependency in injectable.constructor.dependencies) {
            await addInjectableIfExists(
              dependency.lookupKey,
              requestedBy: injectable.clazz,
            );
          }
        }

        for (final factory in lib.factories.where((factory) => factory.clazz == key.root)) {
          final injectable = factory.factory.createdType.lookupKey;
          final injectableSummaries =
              (await _readFromPath(injectable.root, requestedBy: requestedBy)).assistedInjectables;
          final injectableSummary = injectableSummaries.firstWhereOrNull(
            (s) => s.clazz == injectable.root,
          );

          if (injectableSummary != null) {
            final dependencies =
                injectableSummary.constructor.dependencies.where((dependency) => !dependency.isAssisted).toList();

            providersByFactory[key] = DependencyProvidedByFactory._(
              InjectedType(key),
              dependencies,
              factory.clazz,
              factory.factory.name,
              injectableSummary.constructor,
              factory.factory.parameters,
            );

            for (final dependency in dependencies) {
              await addInjectableIfExists(
                dependency.lookupKey,
                requestedBy: injectable.root,
              );
            }
          } else {
            builderContext.rawLogger.severe(
              'Failed to locate factory for injectable ${requestedBy.toAbsoluteUri()} ',
            );
          }
        }
      }
    }

    // The second pass looks at all the dependencies for the providers, and if
    // that dependency isn't already met by a module, it satisfies the
    // dependency by using the type's injectable constructor.
    for (final module in allModules) {
      for (final provider in module.providers) {
        for (final dependency in provider.dependencies) {
          await addInjectableIfExists(
            dependency.lookupKey,
            requestedBy: module.clazz,
          );
        }
      }
    }

    for (final componentProvider in _componentSummary.providers) {
      await addInjectableIfExists(
        componentProvider.injectedType.lookupKey,
        requestedBy: _componentSummary.clazz,
      );
    }

    for (final componentProvider in _componentSummary.providers) {
      await addInjectableIfExists(
        componentProvider.injectedType.lookupKey,
        requestedBy: _componentSummary.clazz,
      );
    }

    // Combined dependencies provided by injectables with those provided by
    // modules, giving modules a higher precedence.
    final mergedDependencies = <LookupKey, ResolvedDependency>{}
      ..addAll(providersByInjectables)
      ..addAll(providersByFactory)
      ..addAll(providersByModules);

    // Providers defined on the component class.
    final componentProviders = <ComponentProvider>[];
    for (final p in _providers) {
      componentProviders.add(
        ComponentProvider._(
          p.injectedType,
          p.name,
          p.kind == ProviderKind.getter,
        ),
      );
    }

    _detectAndWarnAboutCycles(mergedDependencies);

    return ComponentGraph._(
      List<ModuleSummary>.unmodifiable(allModules),
      List<ComponentProvider>.unmodifiable(componentProviders),
      Map<LookupKey, ResolvedDependency>.unmodifiable(mergedDependencies),
    );
  }

  void _detectAndWarnAboutCycles(
    Map<LookupKey, ResolvedDependency> mergedDependencies,
  ) {
    // Symbols we already inspected as potential roots of a cycle.
    final checkedRoots = <LookupKey>{};

    // Keeps track of cycles we already printed so we do not print them again.
    // This can happen when we find the same cycle starting from a different
    // node. Example, the following three are all the same cycle:
    //
    // a -> b -> c -> a
    // b -> c -> a -> b
    // c -> a -> b -> c
    final cycles = <Cycle>{};

    for (final dependency in mergedDependencies.keys) {
      if (checkedRoots.contains(dependency)) {
        // This symbol was already checked.
        continue;
      }
      checkedRoots.add(dependency);

      final chain = <LookupKey>[];
      void checkForCycles(LookupKey parent) {
        final hasCycle = chain.contains(parent);
        chain.add(parent);
        if (hasCycle) {
          final cycle = chain.sublist(chain.indexOf(parent));
          if (cycles.add(Cycle(cycle))) {
            final formattedCycle = cycle.map((s) => '  (${s.toPrettyString()} from ${s.root.path})').join('\n');
            builderContext.rawLogger.severe('Detected dependency cycle:\n$formattedCycle');
          }
        } else {
          mergedDependencies[parent]
              ?.dependencies
              .map((injectedType) => injectedType.lookupKey)
              .forEach(checkForCycles);
        }
        chain.removeLast();
      }

      checkForCycles(dependency);
    }
  }
}

/// An edge in a dependency graph.
@visibleForTesting
class DependencyEdge {
  /// The dependent node in the dependency graph.
  final LookupKey from;

  /// The dependee node in the dependency graph.
  final LookupKey to;

  DependencyEdge({required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencyEdge && runtimeType == other.runtimeType && from == other.from && to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

/// Represents a cycle inside a dependency graph.
///
/// Cycles containing identical sets of nodes and edges are considered equal.
/// For example the following cycles are equal:
///
/// A -> B -> C -> A
/// B -> C -> A -> B
/// C -> A -> B -> C
@visibleForTesting
class Cycle {
  static const SetEquality _setEquality = SetEquality<dynamic>();

  final Set<LookupKey> _nodes;
  final Set<DependencyEdge> _edges;

  Cycle(List<LookupKey> chain)
      : _nodes = chain.toSet(),
        _edges = _computeEdgeSet(chain) {
    assert(chain.length > 1);
    assert(chain.first == chain.last);
    assert(_nodes.length == chain.length - 1);
    assert(_edges.length == chain.length - 1);
  }

  static Set<DependencyEdge> _computeEdgeSet(List<LookupKey> chain) {
    final result = <DependencyEdge>{};
    for (var i = 0; i < chain.length - 1; i++) {
      result.add(DependencyEdge(from: chain[i], to: chain[i + 1]));
    }
    return result;
  }

  /// Hashes only nodes, but not edges, because it should be good enough, and
  /// because hash code must be order-independent.
  // IMPORTANT: we intentionally do not use Quiver's hashObjects because it is
  // order-dependent.
  @override
  int get hashCode => _nodes.fold(0, (hash, s) => hash + s.hashCode);

  @override
  bool operator ==(Object other) {
    if (other is Cycle) {
      return _setEquality.equals(_nodes, other._nodes) && _setEquality.equals(_edges, other._edges);
    }
    return false;
  }
}

/// Logs an error message for a dependency that can not be resolved.
///
/// Since the DI graph can not be created with an unfulfilled dependency, this
/// logs a severe error.
void _logUnresolvedDependency({
  required ComponentSummary componentSummary,
  required SymbolPath dependency,
  required SymbolPath requestedBy,
}) {
  final componentClassName = componentSummary.clazz.symbol;
  final dependencyClassName = dependency.symbol;
  final requestedByClassName = requestedBy.symbol;
  builderContext.rawLogger.severe(
      '''Could not find a way to provide "$dependencyClassName" for component "$componentClassName" which is injected in "$requestedByClassName".

To fix this, check that at least one of the following is true:

- Ensure that $dependencyClassName's class declaration or constructor is annotated with @inject.

- Ensure the constructor is empty or all parameters are provided.

- Ensure $componentClassName contains a module that provides $dependencyClassName.

These classes were found at the following paths:

- Component "$componentClassName": ${componentSummary.clazz.toAbsoluteUri().removeFragment()}.

- Injected class "$dependencyClassName": ${dependency.toAbsoluteUri().removeFragment()}.

- Injected in class "$requestedByClassName": ${requestedBy.toAbsoluteUri().removeFragment()}.
''');
}
