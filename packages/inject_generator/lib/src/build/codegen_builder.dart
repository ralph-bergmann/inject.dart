// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:inject_annotation/inject_annotation.dart';

import '../context.dart';
import '../graph.dart';
import '../source/injected_type.dart';
import '../source/lookup_key.dart';
import '../source/symbol_path.dart';
import '../summary.dart';
import 'abstract_builder.dart';

/// Generates code for a dependency injection-aware library.
class InjectCodegenBuilder extends AbstractInjectBuilder {
  final bool _useScoping;

  const InjectCodegenBuilder({bool useScoping = true}) : _useScoping = useScoping;

  @override
  String get inputExtension => 'summary';

  @override
  String get outputExtension => 'dart';

  @override
  Future<String?> buildOutput(BuildStep buildStep) =>
      runInContext<String?>(buildStep, () => _buildInContext(buildStep));

  Future<String?> _buildInContext(BuildStep buildStep) async {
    // We initially read in our <name>.inject.summary JSON blob, parse it, and
    // use it to generate a "{className}$Component" Dart class for each @component
    // annotation that was processed and put in the summary.
    final summary = await buildStep.readAsString(buildStep.inputId).then(jsonDecode).then(LibrarySummary.fromJson);

    if (summary.components.isEmpty) {
      return null;
    }

    // If we require additional summaries (modules, etc) in other libraries we
    // setup an asset reader that knows how to get the dependencies we need.
    final reader = _AssetSummaryReader(buildStep);

    // This is the library that will be output when done.
    final target = LibraryBuilder();

    // all dependencies used by all components.
    // later used to create the provider classes.
    final dependencies = <ResolvedDependency>{};

    for (final component in summary.components) {
      // Based on this summary, we might need knowledge of other summaries for
      // modules we include, providers we want to generate, etc. Pre-process the
      // summary and get back an object graph.
      final resolver = ComponentGraphResolver(reader, component);
      final graph = await resolver.resolve();
      // graph.debug();

      // Add to the file.
      final (clazz, resolvedDependency) = _ComponentBuilder(summary.assetUri, component, graph).build();

      target.body.add(clazz);
      dependencies.addAll(resolvedDependency);
    }

    for (final dependency in dependencies) {
      target.body.add(
        _ProviderBuilder(summary.assetUri, dependency, dependencies).build(),
      );

      if (dependency is DependencyProvidedByFactory) {
        final builder = _FactoryBuilder(summary.assetUri, dependency, dependencies);
        target.body.add(builder.build());
      }
    }

    final emitter =
        _useScoping ? DartEmitter.scoped(useNullSafetySyntax: true) : DartEmitter(useNullSafetySyntax: true);
    return DartFormatter().format(
      target.build().accept(emitter).toString(),
    );
  }
}

/// A simple implementation wrapping a [BuildStep].
class _AssetSummaryReader implements SummaryReader {
  final BuildStep _buildStep;

  const _AssetSummaryReader(this._buildStep);

  @override
  Future<LibrarySummary> read(String package, String path) =>
      _buildStep.readAsString(AssetId(package, path)).then(jsonDecode).then(LibrarySummary.fromJson);
}

class _Variable {
  final String name;
  final Reference type;

  const _Variable({
    required this.name,
    required this.type,
  });
}

/// Generates code for one component class.
class _ComponentBuilder {
  /// The URI of the library that defines the component.
  ///
  /// Import URIs should be calculated relative to this URI. Because the
  /// generated `.inject.dart` file sits in the same directory as the source
  /// `.dart` file, the relative URIs are compatible between the two.
  final Uri libraryUri;

  final ComponentSummary summary;
  final ComponentGraph graph;

  /// The name of the concrete class that implements the component interface.
  final String concreteName;

  /// The type of the original component interface.
  final Reference componentType;

  /// The generated type of the implementing component class.
  final Reference concreteComponentType;

  /// Dependencies instantiated eagerly during initialization of the component.
  final BlockBuilder preInstantiations = BlockBuilder();

  /// Sorted dependencies handled by this component.
  final Set<ResolvedDependency> _orderedDependencies = <ResolvedDependency>{};

  /// Fields (modules, singletons) on the component class.
  final List<FieldBuilder> fields = <FieldBuilder>[];

  final List<MethodBuilder> methods = <MethodBuilder>[];

  /// The private constructor of the generated component class.
  ///
  /// It has a single parameter for _each_ module that the component uses.
  final ConstructorBuilder constructor = ConstructorBuilder()..name = '_';

  /// The factory of the generated component class.
  ///
  /// It is the entry point to create the dependency graph and provide all injections.
  ///
  /// It has a single parameter for _each_ module that the component uses.
  final ConstructorBuilder factoryConstructor = ConstructorBuilder()
    ..name = 'create'
    ..factory = true
    ..lambda = true;

  factory _ComponentBuilder(
    Uri libraryUri,
    ComponentSummary summary,
    ComponentGraph graph,
  ) {
    final concreteName = '${summary.clazz.symbol}\$Component';
    final componentType = refer(
      summary.clazz.symbol,
      summary.clazz.toDartUri(relativeTo: libraryUri).toString(),
    );
    final concreteComponentType = refer(concreteName);
    return _ComponentBuilder._(
      libraryUri,
      summary,
      graph,
      concreteName,
      componentType,
      concreteComponentType,
    );
  }

  _ComponentBuilder._(
    this.libraryUri,
    this.summary,
    this.graph,
    this.concreteName,
    this.componentType,
    this.concreteComponentType,
  );

  /// Builds a concrete implementation of the given component interface.
  (Class, Set<ResolvedDependency>) build() {
    graph.mergedDependencies.values.forEach(_collectDependencies);
    _generateConstructor();
    _generateInitializeMethod();
    _generateComponentProviders();
    final clazz = Class(
      (b) => b
        ..name = concreteName
        ..implements.add(componentType)
        ..fields.addAll(fields.map((b) => b.build()))
        ..constructors.addAll([factoryConstructor.build(), constructor.build()])
        ..methods.addAll(methods.map((b) => b.build())),
    );
    return (clazz, _orderedDependencies);
  }

  // generates the factory and the private constructor.
  // goes through all modules to add them as field and factory/constructor parameter.
  void _generateConstructor() {
    final moduleVariables = <SymbolPath, _Variable>{};
    final invokeExpressions = <Expression>[];

    for (final moduleSummary in graph.includeModules) {
      final symbolPath = moduleSummary.clazz;
      if (moduleVariables.containsKey(symbolPath)) {
        continue;
      }

      final paramName = symbolPath.symbol.decapitalize();
      final fieldName = '_$paramName';
      final moduleType = _reference(libraryUri, symbolPath);
      fields.add(
        FieldBuilder()
          ..name = fieldName
          ..modifier = FieldModifier.final$
          ..type = moduleType,
      );
      constructor.requiredParameters.add(
        Parameter(
          (b) => b
            ..name = fieldName
            ..toThis = true,
        ),
      );
      factoryConstructor.optionalParameters.add(
        Parameter(
          (b) => b
            ..name = paramName
            ..named = true
            ..required = !moduleSummary.hasDefaultConstructor
            ..type = moduleSummary.hasDefaultConstructor ? moduleType.toNullable() : moduleType,
        ),
      );

      if (moduleSummary.hasDefaultConstructor) {
        invokeExpressions.add(refer(paramName).ifNullThen(moduleType.newInstance(const [])));
      } else {
        invokeExpressions.add(refer(paramName).expression);
      }
      moduleVariables[symbolPath] = _Variable(name: paramName, type: moduleType);
    }

    factoryConstructor.body = concreteComponentType.newInstanceNamed('_', invokeExpressions).code;
  }

  void _generateInitializeMethod() {
    final body = BlockBuilder();

    for (final dependency in _orderedDependencies) {
      final providerClassName = _providerClassName(dependency.injectedType.lookupKey);
      final fieldName = providerClassName.decapitalize();
      fields.add(
        FieldBuilder()
          ..name = fieldName
          ..late = true
          ..modifier = FieldModifier.final$
          ..type = refer(providerClassName),
      );

      // TODO: Find a better way to do this. The order of the [arguments] must
      // be the same as that of the constructor parameters of [_ProviderBuilder].
      final arguments = <Expression>[];
      final seen = <LookupKey>[];

      for (final injected in dependency.dependencies.where((dep) => !dep.isAssisted)) {
        if (seen.contains(injected.lookupKey)) {
          continue;
        }
        seen.add(injected.lookupKey);

        arguments.add(refer(_providerClassName(injected.lookupKey).decapitalize()));
      }

      if (dependency is DependencyProvidedByModule) {
        arguments.add(refer('_${dependency.moduleClass.symbol.decapitalize()}'));
      }
      body.statements.add(
        refer(fieldName)
            .assign(
              refer(providerClassName).newInstance(arguments),
            )
            .statement,
      );
    }
    methods.add(
      MethodBuilder()
        ..name = '_initialize'
        ..returns = refer('void')
        ..body = body.build(),
    );
    constructor.body = refer('_initialize').call(const []).statement;
  }

  // Generate getters/methods for all types the component provides.
  void _generateComponentProviders() {
    for (final provider in graph.providers) {
      final resolved = _orderedDependencies.firstWhereOrNull(
        (element) => element.injectedType.lookupKey == provider.injectedType.lookupKey,
      );
      if (resolved == null) {
        throw _UnresolvedDependencyForComponentError(
          component: summary.clazz,
          injected: provider.injectedType.lookupKey,
        );
      }

      final resolvedIsNullable = resolved.injectedType.isNullable;
      final injectedIsNullable = provider.injectedType.isNullable;
      if (!injectedIsNullable && resolvedIsNullable) {
        _logNullabilityMismatchDependency(
          dependency: provider.injectedType,
          requestedBy: summary.clazz,
          resolved: resolved,
        );
      }

      // Factories are never asynchronous themselves,
      // even if their create method is asynchronous.
      final asynchronous =
          resolved is! DependencyProvidedByFactory && provider.injectedType.asynchronous(_orderedDependencies);

      final returnType = _referenceForType(
        libraryUri,
        provider.injectedType,
        asFuture: asynchronous,
      );

      final providerClassName = _providerClassName(provider.injectedType.lookupKey).decapitalize();
      final ref = provider.injectedType.isProvider ? refer(providerClassName) : refer('$providerClassName.get()');

      final method = MethodBuilder()
        ..name = provider.methodName
        ..returns = returnType
        ..type = provider.isGetter ? MethodType.getter : null
        ..lambda = true
        ..body = ref.code
        ..annotations.add(refer('override'));
      methods.add(method);
    }
  }

  // Sorts all dependencies so that all can be fulfilled.
  void _collectDependencies(ResolvedDependency? dep) {
    if (dep == null || _orderedDependencies.contains(dep)) {
      return;
    }

    for (final depDep in dep.dependencies) {
      _collectDependencies(graph.mergedDependencies[depDep.lookupKey]);
    }

    _orderedDependencies.add(dep);
  }
}

/// Generates code for a [Provider] class for the [dependency].
class _ProviderBuilder {
  /// The URI of the library that defines the provider.
  ///
  /// Import URIs should be calculated relative to this URI. Because the
  /// generated `.inject.dart` file sits in the same directory as the source
  /// `.dart` file, the relative URIs are compatible between the two.
  final Uri libraryUri;

  /// The [dependency] this provider provides.
  final ResolvedDependency dependency;

  /// All dependencies of all components.
  final Set<ResolvedDependency> dependencies;

  /// The constructor of the generated provider class.
  ///
  /// If a module provides the dependency, the constructor has a parameter of
  /// the type of this module. Otherwise, the constructor has no parameters.
  final ConstructorBuilder constructor = ConstructorBuilder()..constant = true;

  /// The `get()` method.
  final MethodBuilder methodBuilder = MethodBuilder();

  /// Fields to hold references to dependencies used by the provider.
  final List<FieldBuilder> fields = <FieldBuilder>[];

  factory _ProviderBuilder(
    Uri libraryUri,
    ResolvedDependency dependency,
    Set<ResolvedDependency> dependencies,
  ) =>
      _ProviderBuilder._(
        libraryUri,
        dependency,
        dependencies,
      );

  _ProviderBuilder._(
    this.libraryUri,
    this.dependency,
    this.dependencies,
  );

  Class build() {
    _generateConstructor();

    var asynchronous = switch (dependency) {
      DependencyProvidedByModule() => _buildProvidedByModule(dependency as DependencyProvidedByModule),
      DependencyProvidedByInjectable() => _buildProvidedByInjectable(dependency as DependencyProvidedByInjectable),
      DependencyProvidedByFactory() => _buildProvidedByFactory(dependency as DependencyProvidedByFactory),
    };

    asynchronous = asynchronous || dependency.injectedType.isAsynchronous;

    var providerType = _referenceForKey(libraryUri, dependency.injectedType.lookupKey);
    if (dependency.injectedType.isNullable) {
      providerType = providerType.toNullable();
    }
    if (asynchronous) {
      providerType = providerType.toFuture();
    }

    methodBuilder
      ..name = 'get'
      ..returns = providerType
      ..annotations.add(refer('override'))
      ..lambda = true
      ..modifier = asynchronous ? MethodModifier.async : null;

    return Class(
      (b) => b
        ..name = _providerClassName(dependency.injectedType.lookupKey)
        ..implements.add(providerType.toProvider())
        ..constructors.add(constructor.build())
        ..fields.addAll(fields.map((b) => b.build()))
        ..methods.add(methodBuilder.build()),
    );
  }

  // generates the constructor.
  // goes through all dependencies to add them as field and constructor parameter.
  void _generateConstructor() {
    final seen = <LookupKey>[];
    for (final injected in dependency.dependencies.where((dep) => !dep.isAssisted)) {
      final resolved = dependencies.firstWhereOrNull(
        (element) => element.injectedType.lookupKey == injected.lookupKey,
      );
      if (resolved == null) {
        throw _UnresolvedDependencyForProviderError(
          requestedBy: dependency.injectedType.lookupKey,
          injected: injected.lookupKey,
        );
      }

      if (seen.contains(injected.lookupKey)) {
        continue;
      }
      seen.add(injected.lookupKey);

      final type = _providerClassName(injected.lookupKey);
      final fieldName = type.decapitalize();
      fields.add(
        FieldBuilder()
          ..name = fieldName
          ..modifier = FieldModifier.final$
          ..type = refer(type),
      );
      constructor.requiredParameters.add(
        Parameter(
          (b) => b
            ..name = fieldName
            ..toThis = true,
        ),
      );
    }
  }

  bool _buildProvidedByModule(DependencyProvidedByModule dep) {
    var asynchronous = false;
    const moduleFieldName = '_module';
    fields.add(
      FieldBuilder()
        ..name = moduleFieldName
        ..modifier = FieldModifier.final$
        ..type = _reference(libraryUri, dep.moduleClass),
    );
    constructor.requiredParameters.add(
      Parameter(
        (b) => b
          ..name = moduleFieldName
          ..toThis = true,
      ),
    );

    final isSingleton = dep.injectedType.isSingleton;
    const singletonFieldName = '_singleton';
    if (isSingleton) {
      constructor.constant = false;
      fields.add(
        FieldBuilder()
          ..name = singletonFieldName
          ..type = _referenceForKey(
            libraryUri,
            dep.injectedType.lookupKey,
          ).toNullable(),
      );
    }

    final positionalArguments = <Expression>[];
    final namedArguments = <String, Expression>{};

    for (final injected in dep.dependencies.where((dep) => !dep.isAssisted)) {
      final resolved = dependencies.firstWhere(
        (dep) => dep.injectedType.lookupKey == injected.lookupKey,
      );
      final resolvedIsNullable = resolved.injectedType.isNullable;
      final injectedIsNullable = injected.isNullable;
      if (!injectedIsNullable && resolvedIsNullable) {
        _logNullabilityMismatchDependency(
          dependency: injected,
          requestedBy: dep.moduleClass,
          resolved: resolved,
        );
      }

      final type = _providerClassName(injected.lookupKey);
      final fieldName = type.decapitalize();
      final isProvider = injected.isProvider;
      final ref = isProvider ? refer(fieldName) : refer('$fieldName.get()');
      final injectAsynchronously = injected.asynchronous(dependencies);
      asynchronous = injectAsynchronously || asynchronous;
      if (injected.isNamed) {
        namedArguments[injected.name!] = injectAsynchronously ? ref.awaited : ref;
      } else {
        positionalArguments.add(injectAsynchronously ? ref.awaited : ref);
      }
    }

    var provider = refer('$moduleFieldName.${dep.methodName}').call(positionalArguments, namedArguments);
    if (dep.injectedType.isAsynchronous) {
      provider = provider.awaited;
    }
    if (isSingleton) {
      provider = refer(singletonFieldName).assignNullAware(provider);
    }

    methodBuilder.body = provider.code;

    return asynchronous;
  }

  bool _buildProvidedByInjectable(DependencyProvidedByInjectable dep) {
    var asynchronous = false;
    final isSingleton = dep.injectedType.isSingleton;
    const singletonFieldName = '_singleton';
    if (isSingleton) {
      constructor.constant = false;
      fields.add(
        FieldBuilder()
          ..name = singletonFieldName
          ..type = _referenceForKey(
            libraryUri,
            dep.injectedType.lookupKey,
          ).toNullable(),
      );
    }

    final positionalArguments = <Expression>[];
    final namedArguments = <String, Expression>{};
    for (final injected in dep.dependencies.where((dep) => !dep.isAssisted)) {
      final type = _providerClassName(injected.lookupKey);
      final fieldName = type.decapitalize();
      final isProvider = injected.isProvider;
      final ref = isProvider ? refer(fieldName) : refer('$fieldName.get()');
      final injectAsynchronously = injected.asynchronous(dependencies);
      asynchronous = injectAsynchronously || asynchronous;
      if (injected.isNamed) {
        namedArguments[injected.name!] = injectAsynchronously ? ref.awaited : ref;
      } else {
        positionalArguments.add(injectAsynchronously ? ref.awaited : ref);
      }
    }

    var provider = _referenceForKey(libraryUri, dep.injectedType.lookupKey).call(positionalArguments, namedArguments);
    if (isSingleton) {
      provider = refer(singletonFieldName).assignNullAware(provider);
    }

    methodBuilder.body = provider.code;

    return asynchronous;
  }

  bool _buildProvidedByFactory(DependencyProvidedByFactory dep) {
    constructor.constant = false;

    const fieldName = '_factory';

    final params = dep.dependencies
        .where((dep) => !dep.isAssisted)
        .map((dep) => _providerClassName(dep.lookupKey))
        .map((dep) => dep.decapitalize())
        .map(refer)
        .toSet()
        .toList();

    fields.add(
      FieldBuilder()
        ..name = fieldName
        ..late = true
        ..modifier = FieldModifier.final$
        ..type = _referenceForKey(libraryUri, dep.injectedType.lookupKey)
        ..assignment = params.isEmpty
            ? refer(_factoryClassName(dep.injectedType.lookupKey)).constInstance([]).code
            : refer(_factoryClassName(dep.injectedType.lookupKey)).newInstance(params).code,
    );

    methodBuilder.body = refer(fieldName).code;

    return false;
  }
}

/// Generates code for one assisted inject factory class.
class _FactoryBuilder {
  /// The URI of the library that defines the factory.
  ///
  /// Import URIs should be calculated relative to this URI. Because the
  /// generated `.inject.dart` file sits in the same directory as the source
  /// `.dart` file, the relative URIs are compatible between the two.
  final Uri libraryUri;

  /// The [dependency] this factory creates.
  final DependencyProvidedByFactory dependency;

  /// All dependencies of all components.
  final Set<ResolvedDependency> dependencies;

  /// The name of the concrete class that implements the factory interface.
  final String factoryClassName;

  /// The type of the original factory interface.
  final TypeReference factoryType;

  /// Whether it is an asynchronous factory or not.
  final bool asynchronous;

  factory _FactoryBuilder(
    Uri libraryUri,
    DependencyProvidedByFactory dependency,
    Set<ResolvedDependency> dependencies,
  ) {
    final factoryClassName = _factoryClassName(dependency.injectedType.lookupKey);
    final isAsynchronous = dependency.asynchronous(dependencies);
    return _FactoryBuilder._(
      libraryUri,
      dependency,
      dependencies,
      factoryClassName,
      _referenceForKey(libraryUri, dependency.injectedType.lookupKey),
      isAsynchronous,
    );
  }

  const _FactoryBuilder._(
    this.libraryUri,
    this.dependency,
    this.dependencies,
    this.factoryClassName,
    this.factoryType,
    this.asynchronous,
  );

  /// Builds a concrete implementation of the factory.
  Class build() {
    final createdType = _referenceForKey(
      libraryUri,
      dependency.createdType.injectedType.lookupKey,
    );

    final constructor = ConstructorBuilder()..constant = true;
    final fields = <FieldBuilder>[];
    final createMethod = MethodBuilder()
      ..name = dependency.methodName
      ..returns = asynchronous ? createdType.toFuture() : createdType
      ..annotations.add(refer('override'))
      ..modifier = asynchronous ? MethodModifier.async : null;

    final positionalArguments = <Expression>[];
    final namedArguments = <String, Expression>{};
    final seen = <LookupKey>[];

    // generate constructor, fields and arguments for the create method from
    // createdType dependencies
    for (final injected in dependency.createdType.dependencies) {
      final isSeen = seen.contains(injected.lookupKey);
      seen.add(injected.lookupKey);

      final isAssisted = injected.isAssisted;
      final providerFieldName = _providerClassName(injected.lookupKey).decapitalize();

      //
      // add not assisted dependencies as constructor parameter
      //

      if (!isSeen && !isAssisted) {
        final resolved = dependencies.firstWhereOrNull(
          (element) => element.injectedType.lookupKey == injected.lookupKey,
        );
        if (resolved == null) {
          throw _UnresolvedDependencyForFactoryError(
            factory: dependency.factoryClass,
            requestedBy: dependency.injectedType.lookupKey,
            injected: injected.lookupKey,
          );
        }

        constructor.requiredParameters.add(
          Parameter(
            (b) => b
              ..name = providerFieldName
              ..toThis = true,
          ),
        );
        fields.add(
          FieldBuilder()
            ..name = providerFieldName
            ..modifier = FieldModifier.final$
            ..type = refer(_providerClassName(injected.lookupKey)),
        );
      }

      //
      // generate create method parameters
      //

      if (isAssisted) {
        var type = _referenceForKey(libraryUri, injected.lookupKey);
        if (injected.isNullable) {
          type = type.toNullable();
        }

        if (injected.isRequired && !injected.isNamed) {
          createMethod.requiredParameters.add(
            Parameter(
              (b) => b
                ..name = injected.name!
                ..type = type,
            ),
          );
        } else {
          createMethod.optionalParameters.add(
            Parameter(
              (b) => b
                ..name = injected.name!
                ..named = injected.isNamed
                ..required = injected.isRequired
                ..type = type,
            ),
          );
        }
      }

      //
      // generate arguments to create the type
      //

      final isProvider = injected.isProvider;
      final isAsynchronous = injected.asynchronous(dependencies);
      final Expression argRef;
      if (isAssisted) {
        argRef = refer(injected.name!);
      } else {
        if (isProvider) {
          argRef = refer(providerFieldName);
        } else if (isAsynchronous) {
          argRef = refer('$providerFieldName.get()').awaited;
        } else {
          argRef = refer('$providerFieldName.get()');
        }
      }

      if (injected.isNamed) {
        namedArguments[injected.name!] = argRef;
      } else {
        positionalArguments.add(argRef);
      }
    }

    // generate the body of the create method
    createMethod.body = createdType.call(positionalArguments, namedArguments).code;

    return Class(
      (b) => b
        ..name = factoryClassName
        ..implements.add(factoryType)
        ..fields.addAll(fields.map((b) => b.build()))
        ..constructors.add(constructor.build())
        ..methods.add(createMethod.build()),
    );
  }
}

String _providerClassName(LookupKey key) => '_${key.toClassName().capitalize()}\$Provider';

String _factoryClassName(LookupKey key) => '_${key.toClassName().capitalize()}\$Factory';

TypeReference _referenceForType(
  Uri libraryUri,
  InjectedType injectedType, {
  bool asFuture = false,
}) {
  var keyReference = _referenceForKey(libraryUri, injectedType.lookupKey);
  if (injectedType.isNullable) {
    keyReference = keyReference.toNullable();
  }
  if (asFuture || injectedType.isAsynchronous) {
    keyReference = keyReference.toFuture();
  }
  if (injectedType.isProvider) {
    keyReference = keyReference.toProvider();
  }
  return keyReference;
}

TypeReference _referenceForKey(Uri libraryUri, LookupKey key) {
  final ref = _reference(libraryUri, key.root);

  final typeArguments = key.typeArguments;
  if (typeArguments == null || typeArguments.isEmpty) {
    return ref;
  }

  return (ref.toBuilder()
        ..types.addAll(
          typeArguments.map((typeArgument) => _reference(libraryUri, typeArgument)).toList(),
        ))
      .build();
}

TypeReference _reference(Uri libraryUri, SymbolPath symbolPath) => TypeReference(
      (b) => b
        ..symbol = symbolPath.symbol
        ..url = symbolPath.toDartUri(relativeTo: libraryUri).toString(),
    );

extension _ResolvedDependencyExtension on ResolvedDependency {
  /// Whether this or one of its dependencies is asynchronous.
  /// [knownDependencies] list of all known dependencies to look up.
  bool asynchronous(Iterable<ResolvedDependency> knownDependencies) {
    if (injectedType.isAsynchronous) {
      return true;
    }

    return dependencies
        .where((dep) => !dep.isAssisted)
        .map(
          (dep) => knownDependencies.firstWhereOrNull(
            (element) => dep.lookupKey == element.injectedType.lookupKey,
          ),
        )
        .any((dep) => dep?.asynchronous(knownDependencies) ?? false);
  }
}

extension _InjectedTypeExtension on InjectedType {
  bool asynchronous(Iterable<ResolvedDependency> dependencies) =>
      dependencies
          .firstWhereOrNull(
            (element) => lookupKey == element.injectedType.lookupKey,
          )
          ?.asynchronous(dependencies) ??
      false;
}

extension _TypeReferenceExtension on TypeReference {
  TypeReference toNullable() => (toBuilder()..isNullable = true).build();

  TypeReference toFuture() {
    if (symbol == 'Future' && url == 'dart:async') {
      return this;
    }

    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..url = 'dart:async'
        ..types.add(this),
    );
  }

  TypeReference toProvider() {
    if (symbol == 'Provider' && url == 'package:inject_annotation/inject_annotation.dart') {
      return this;
    }

    return TypeReference(
      (b) => b
        ..symbol = 'Provider'
        ..url = 'package:inject_annotation/inject_annotation.dart'
        ..types.add(this),
    );
  }
}

extension Capitalize on String {
  String capitalize() => splitMapJoin(
        RegExp(r'^((_)*[a-z])'),
        onMatch: (m) => '${m[0]}'.toUpperCase(),
        onNonMatch: (s) => s,
      );

  String decapitalize() => splitMapJoin(
        RegExp(r'^((_)*[A-Z])'),
        onMatch: (m) => '${m[0]}'.toLowerCase(),
        onNonMatch: (s) => s,
      );
}

/// Logs an error message for a dependency that was resolved but has not the
/// required nullabliity.
///
/// Since the DI graph can not be created with an unfulfilled dependency, this
/// logs a severe error.
void _logNullabilityMismatchDependency({
  required InjectedType dependency,
  required SymbolPath requestedBy,
  required ResolvedDependency resolved,
}) {
  final dependencyClassName = dependency.lookupKey.toPrettyString();

  final SymbolPath resolvedSymbolPath;
  if (resolved is DependencyProvidedByModule) {
    resolvedSymbolPath = resolved.moduleClass;
  } else if (resolved is DependencyProvidedByFactory) {
    resolvedSymbolPath = resolved.injectedType.lookupKey.root;
  } else {
    resolvedSymbolPath = resolved.injectedType.lookupKey.root;
  }

  builderContext.rawLogger
      .severe('''Could not find a way to provide "$dependencyClassName" which is injected in "${requestedBy.symbol}".

The injected type was found, but the provided type is nullable, while the injected type is not.

You have two options to fix this:

- Ensure that the type "$dependencyClassName" is provided as non-nullable.

- Ensure that the class "${requestedBy.symbol}" accepts the type as nullable.

These classes were found at the following paths:

- Injected class "$dependencyClassName": ${dependency.lookupKey.root.toAbsoluteUri().removeFragment()}.

- Injected in class "${requestedBy.symbol}": ${requestedBy.toAbsoluteUri().removeFragment()}.

- Provider "${resolvedSymbolPath.symbol}": ${resolvedSymbolPath.toAbsoluteUri().removeFragment()}.
''');
}

/// Error for a dependency that can not be resolved.
class _UnresolvedDependencyForComponentError extends Error {
  final String componentClassName;
  final String dependencyClassName;
  final Uri pathToComponent;
  final Uri pathToInjected;

  _UnresolvedDependencyForComponentError({
    required SymbolPath component,
    required LookupKey injected,
  })  : componentClassName = component.symbol,
        dependencyClassName = injected.toPrettyString(),
        pathToComponent = component.toAbsoluteUri().removeFragment(),
        pathToInjected = injected.root.toAbsoluteUri().removeFragment();

  @override
  String toString() => '''Could not find a way to provide "$dependencyClassName" for component "$componentClassName".

To fix this, check that at least one of the following is true:

- Ensure that $dependencyClassName's class declaration or constructor is annotated with @inject.

- Ensure the constructor is empty or all parameters are provided.

- Ensure "$componentClassName" component annotation contains a module that provides "$dependencyClassName".

These classes were found at the following paths:

- Component "$componentClassName": $pathToComponent}.

- Injected class "$dependencyClassName": $pathToInjected}.

''';
}

/// Error for a dependency that can not be resolved.
class _UnresolvedDependencyForProviderError extends Error {
  final String requestedByClassName;
  final String dependencyClassName;
  final Uri pathToRequestedBy;
  final Uri pathToInjected;

  _UnresolvedDependencyForProviderError({
    required LookupKey requestedBy,
    required LookupKey injected,
  })  : requestedByClassName = requestedBy.toPrettyString(),
        dependencyClassName = injected.toPrettyString(),
        pathToRequestedBy = requestedBy.root.toAbsoluteUri().removeFragment(),
        pathToInjected = injected.root.toAbsoluteUri().removeFragment();

  @override
  String toString() => '''Could not find a way to provide "$dependencyClassName" for class "$requestedByClassName".

To fix this, check that at least one of the following is true:

- Ensure that $dependencyClassName's class declaration or constructor is annotated with @inject.

- Ensure the constructor is empty or all parameters are provided.

- Ensure you created a module that provides "$dependencyClassName".

These classes were found at the following paths:

- Class "$requestedByClassName": $pathToRequestedBy}.

- Injected class "$dependencyClassName": $pathToInjected}.

''';
}

/// Error for a dependency that can not be resolved.
class _UnresolvedDependencyForFactoryError extends Error {
  final String factoryClassName;
  final String requestedByClassName;
  final String dependencyClassName;
  final Uri pathToFactory;
  final Uri pathToRequestedBy;
  final Uri pathToInjected;

  _UnresolvedDependencyForFactoryError({
    required SymbolPath factory,
    required LookupKey requestedBy,
    required LookupKey injected,
  })  : factoryClassName = factory.symbol,
        requestedByClassName = requestedBy.toPrettyString(),
        dependencyClassName = injected.toPrettyString(),
        pathToFactory = factory.toAbsoluteUri().removeFragment(),
        pathToRequestedBy = requestedBy.root.toAbsoluteUri().removeFragment(),
        pathToInjected = injected.root.toAbsoluteUri().removeFragment();

  @override
  String toString() =>
      '''Could not find a way to provide "$dependencyClassName" for class "$requestedByClassName" created by factory "$factoryClassName".

To fix this, check that at least one of the following is true:

- Ensure that $dependencyClassName's class declaration or constructor is annotated with @inject.

- Ensure the constructor is empty or all parameters are provided.

- Ensure you created a module that provides "$dependencyClassName".

These classes were found at the following paths:

- Factory "$factoryClassName": $pathToFactory}.

- Class "$requestedByClassName": $pathToRequestedBy}.

- Injected class "$dependencyClassName": $pathToInjected}.

''';
}
