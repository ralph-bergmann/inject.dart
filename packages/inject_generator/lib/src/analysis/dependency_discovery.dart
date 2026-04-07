import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../inject_generator.dart' show InjectBuilder;
import '../builder/inject_builder.dart' show InjectBuilder;
import '../codegen/code_generator.dart' show CodeGenerator;
import '../codegen/naming.dart';
import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../validation/binding_key.dart';
import 'annotation_reader.dart';
import 'assisted_reader.dart';
import 'component_reader.dart';
import 'inject_reader.dart';
import 'module_reader.dart';

/// Collects all [BindingKey]s provided by [modules].
///
/// For `@asynchronous` providers returning `Future<T>`, both the
/// unwrapped `T` key (from `ProviderDescriptor.key`) and a separate
/// `Future<T>` key are included so that downstream dependency checks
/// match both the unwrapped and the original binding type.
Set<BindingKey> collectModuleProvidedKeys(
  List<({ClassElement moduleClass, ModuleData moduleData})> modules,
) {
  final result = <BindingKey>{};
  for (final m in modules) {
    for (final ProviderDescriptor provider in m.moduleData.providers) {
      result.add(provider.key);
      if (provider.metadata.isAsynchronous) {
        // provider.key is built from the unwrapped type (T).
        // For @asynchronous providers we also need the Future<T> key
        // so that entry points returning Future<T> are matched.
        final BindingKey? futureKey = BindingKey.fromDartType(
          provider.returnType,
          qualifier: provider.metadata.qualifier,
        );
        if (futureKey != null) {
          result.add(futureKey);
        }
      }
    }
  }
  return result;
}

/// Discovers `@inject`-annotated classes referenced by entry points
/// or as dependencies of module providers.
///
/// Shared by [CodeGenerator] and [InjectBuilder] to avoid duplication.
void discoverInjectables({
  required AnnotationReader reader,
  required ComponentData componentData,
  required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
      const [],
}) {
  // Collect all types provided by modules
  final Set<BindingKey> moduleProvidedKeys = collectModuleProvidedKeys(modules);

  // Check entry point types not covered by modules
  for (final EntryPoint ep in componentData.entryPoints) {
    final Element element = ep.element;
    final DartType? returnType = element.entryPointReturnType;
    if (returnType == null) {
      continue;
    }

    // Unwrap Provider<T> and Future<T> wrappers so that we discover
    // the inner type T as the injectable, not Future or Provider.
    final DartType resolvedType = returnType.unwrapProviderAndFuture().resolvedType;

    final BindingKey? resolvedKey = BindingKey.fromDartType(resolvedType, qualifier: ep.key.qualifier);
    if (resolvedKey != null && moduleProvidedKeys.contains(resolvedKey)) {
      continue;
    }

    // Also check if the original return type matches a module-provided key
    // (module keys include Future<T> for @asynchronous providers)
    if (returnType != resolvedType) {
      final BindingKey? returnKey = BindingKey.fromDartType(returnType, qualifier: ep.key.qualifier);
      if (returnKey != null && moduleProvidedKeys.contains(returnKey)) {
        continue;
      }
    }

    // Skip @assistedFactory types and synthesized factory types
    // (handled by discoverAssistedFactories)
    if (resolvedType case final InterfaceType interfaceType) {
      if (interfaceType.element case final ClassElement classEl) {
        if (reader.isAssistedFactory(classEl)) {
          continue;
        }
        if (factories.any((f) => f.factoryElement == classEl)) {
          continue;
        }
      }
    }

    _findAndAddInjectable(
      dartType: resolvedType,
      reader: reader,
      injectables: injectables,
      moduleProvidedKeys: moduleProvidedKeys,
      factories: factories,
      qualifier: ep.key.qualifier,
    );
  }

  for (final module in modules) {
    for (final ProviderDescriptor provider in module.moduleData.providers) {
      for (final ParameterDependency dependency in provider.dependencies) {
        final BindingKey? depKey = BindingKey.fromDartType(dependency.type, qualifier: dependency.qualifier);
        if (depKey != null && moduleProvidedKeys.contains(depKey)) {
          continue;
        }

        _findAndAddInjectable(
          dartType: dependency.type,
          reader: reader,
          injectables: injectables,
          moduleProvidedKeys: moduleProvidedKeys,
          factories: factories,
          qualifier: dependency.qualifier,
        );
      }
    }
  }
}

/// Discovers factory classes referenced by entry points or as module dependencies.
///
/// Handles both explicit `@assistedFactory`-annotated classes and synthesized
/// factories (generated abstract classes from `@assistedInject` without an
/// explicit `@assistedFactory`).
///
/// For each factory found, also discovers its injected dependencies
/// (from the `@assistedInject` target) and adds them to [injectables].
void discoverAssistedFactories({
  required AnnotationReader reader,
  required ComponentData componentData,
  required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
  factories,
}) {
  final Set<BindingKey> moduleProvidedKeys = collectModuleProvidedKeys(modules);

  // Scan entry points for factories (explicit and synthesized)
  for (final EntryPoint ep in componentData.entryPoints) {
    final Element element = ep.element;
    final DartType? returnType = element.entryPointReturnType;
    if (returnType == null) {
      continue;
    }

    // Unwrap Provider<T> and Future<T> wrappers
    final DartType resolvedType = returnType.unwrapProviderAndFuture().resolvedType;

    _tryDiscoverFactory(
      dartType: resolvedType,
      reader: reader,
      factories: factories,
      injectables: injectables,
      moduleProvidedKeys: moduleProvidedKeys,
    );
  }

  // Scan module dependencies for factories
  for (final module in modules) {
    for (final ProviderDescriptor provider in module.moduleData.providers) {
      for (final ParameterDependency dependency in provider.dependencies) {
        _tryDiscoverFactory(
          dartType: dependency.type,
          reader: reader,
          factories: factories,
          injectables: injectables,
          moduleProvidedKeys: moduleProvidedKeys,
        );
      }
    }
  }
}

/// Tries to discover a factory (explicit or synthesized) from [dartType].
void _tryDiscoverFactory({
  required DartType dartType,
  required AnnotationReader reader,
  required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
  factories,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required Set<BindingKey> moduleProvidedKeys,
}) {
  if (dartType case final InterfaceType interfaceType) {
    if (interfaceType.element case final ClassElement classEl) {
      // Deduplicate: skip if already discovered
      if (factories.any((f) => f.factoryElement == classEl)) {
        return;
      }

      // Case 1: Explicit @assistedFactory
      if (reader.isAssistedFactory(classEl)) {
        _discoverExplicitFactory(
          classEl: classEl,
          reader: reader,
          factories: factories,
          injectables: injectables,
          moduleProvidedKeys: moduleProvidedKeys,
        );
        return;
      }

      // Case 2: Synthesized factory (generated abstract class)
      _discoverSynthesizedFactory(
        classEl: classEl,
        reader: reader,
        factories: factories,
        injectables: injectables,
        moduleProvidedKeys: moduleProvidedKeys,
      );
    }
  }
}

/// Discovers an explicit `@assistedFactory`-annotated factory.
void _discoverExplicitFactory({
  required ClassElement classEl,
  required AnnotationReader reader,
  required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
  factories,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required Set<BindingKey> moduleProvidedKeys,
}) {
  final AssistedFactoryData? factoryData = reader.readAssistedFactory(classEl);
  if (factoryData == null) {
    return;
  }

  if (factoryData.targetType case final InterfaceType targetInterfaceType) {
    if (targetInterfaceType.element case final ClassElement targetClassElement) {
      final List<AssistedInjectData> allInjectData = reader.readAssistedInjects(targetClassElement);
      AssistedInjectData? injectData = allInjectData
          .where(
            (d) => d.key.qualifier == factoryData.targetQualifier,
          )
          .firstOrNull;
      // Fallback: unqualified factory with exactly one @assistedInject constructor.
      if (injectData == null && factoryData.targetQualifier == null && allInjectData.length == 1) {
        injectData = allInjectData.first;
      }
      if (injectData == null) {
        return;
      }

      factories.add((factoryElement: classEl, injectData: injectData, factoryData: factoryData));

      _discoverFactoryDependencies(
        injectData: injectData,
        reader: reader,
        injectables: injectables,
        factories: factories,
        moduleProvidedKeys: moduleProvidedKeys,
      );
    }
  }
}

/// Discovers a synthesized factory from a generated abstract class.
///
/// A synthesized factory is detected when:
/// - The class is abstract with exactly one abstract method named `create`
/// - The method's return type is a class with `@assistedInject`
/// - The class name matches [synthesizedFactoryClassName] for one of the
///   target class's `@assistedInject` constructors
void _discoverSynthesizedFactory({
  required ClassElement classEl,
  required AnnotationReader reader,
  required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
  factories,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required Set<BindingKey> moduleProvidedKeys,
}) {
  if (!classEl.isAbstract) {
    return;
  }

  final List<MethodElement> abstractMethods = classEl.methods.where((m) => m.isAbstract).toList();
  // Each synthesized factory has exactly one abstract method named 'create'.
  if (abstractMethods.length != 1 || abstractMethods.first.name != 'create') {
    return;
  }

  final MethodElement createMethod = abstractMethods.first;
  final DartType targetType = createMethod.returnType;

  if (targetType case final InterfaceType targetInterfaceType) {
    if (targetInterfaceType.element case final ClassElement targetClassElement) {
      if (!reader.isAssistedInject(targetClassElement)) {
        return;
      }

      final List<AssistedInjectData> allInjectData = reader.readAssistedInjects(targetClassElement);
      if (allInjectData.isEmpty) {
        return;
      }

      // Find the @assistedInject entry whose expected factory name matches classEl.
      // isMulti drives the qualifier-suffix convention.
      final bool isMulti = allInjectData.length > 1;
      AssistedInjectData? matchingInjectData;
      for (final injectData in allInjectData) {
        final String? factoryQualifier = isMulti ? injectData.key.qualifier : null;
        if (classEl.name == synthesizedFactoryClassName(targetClassElement.name!, factoryQualifier)) {
          matchingInjectData = injectData;
          break;
        }
      }

      if (matchingInjectData == null) {
        return;
      }

      // Validate return type matches target class.
      if (createMethod.returnType case final InterfaceType returnType) {
        if (returnType.element != targetClassElement) {
          return;
        }
      } else {
        return;
      }

      // Validate parameter signatures match @assisted parameters
      // (count, positional types by position, named types by name).
      final List<FormalParameterElement> methodParams = createMethod.formalParameters.toList();
      final List<ParameterDependency> targetParams = matchingInjectData.assistedParameters;
      if (methodParams.length != targetParams.length) {
        return;
      }
      final List<FormalParameterElement> positionalMethod = methodParams.where((p) => !p.isNamed).toList();
      final List<ParameterDependency> positionalTarget = targetParams.where((p) => !p.parameter.isNamed).toList();
      var signaturesMatch = positionalMethod.length == positionalTarget.length;
      if (signaturesMatch) {
        for (var i = 0; i < positionalMethod.length; i++) {
          if (positionalMethod[i].type != positionalTarget[i].type) {
            signaturesMatch = false;
            break;
          }
        }
      }
      if (signaturesMatch) {
        final Map<String?, ParameterDependency> namedTarget = {
          for (final p in targetParams.where((p) => p.parameter.isNamed)) p.parameter.name: p,
        };
        for (final FormalParameterElement mp in methodParams.where((p) => p.isNamed)) {
          final ParameterDependency? tp = namedTarget[mp.name];
          if (tp == null || mp.type != tp.type) {
            signaturesMatch = false;
            break;
          }
        }
      }
      if (!signaturesMatch) {
        return;
      }

      final assistedParameters = <ParameterDependency>[
        for (final param in createMethod.formalParameters)
          (parameter: param, type: param.type, qualifier: null, isProvider: false),
      ];

      final AssistedFactoryData factoryData = (
        factoryElement: classEl,
        createMethod: createMethod,
        targetType: targetType,
        targetQualifier: matchingInjectData.key.qualifier,
        assistedParameters: assistedParameters,
      );

      factories.add((factoryElement: classEl, injectData: matchingInjectData, factoryData: factoryData));

      _discoverFactoryDependencies(
        injectData: matchingInjectData,
        reader: reader,
        injectables: injectables,
        factories: factories,
        moduleProvidedKeys: moduleProvidedKeys,
      );
    }
  }
}

/// Discovers injected dependencies of a factory's target class.
///
/// For each injected dependency, first tries to discover it as a factory
/// (explicit or synthesized), then falls back to injectable discovery.
/// This enables transitive factory chains (e.g., FactoryA → TargetA → FactoryB).
void _discoverFactoryDependencies({
  required AssistedInjectData injectData,
  required AnnotationReader reader,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
  factories,
  required Set<BindingKey> moduleProvidedKeys,
}) {
  for (final ParameterDependency dep in injectData.injectedDependencies) {
    final BindingKey? depKey = BindingKey.fromDartType(dep.type, qualifier: dep.qualifier);
    if (depKey != null && moduleProvidedKeys.contains(depKey)) {
      continue;
    }

    // Skip typedef function type deps — they're handled by discoverTypedefProviders
    if (dep.type is FunctionType && (dep.type as FunctionType).alias != null) {
      continue;
    }

    // Try to discover as a factory first (handles nested factory deps)
    var discoveredAsFactory = false;
    if (dep.type case final InterfaceType interfaceType) {
      if (interfaceType.element case final ClassElement classEl) {
        if (!factories.any((f) => f.factoryElement == classEl)) {
          if (reader.isAssistedFactory(classEl)) {
            _discoverExplicitFactory(
              classEl: classEl,
              reader: reader,
              factories: factories,
              injectables: injectables,
              moduleProvidedKeys: moduleProvidedKeys,
            );
            discoveredAsFactory = true;
          } else {
            // Also try synthesized factories (generated abstract classes
            // from @assistedInject without an explicit @assistedFactory).
            final int countBefore = factories.length;
            _discoverSynthesizedFactory(
              classEl: classEl,
              reader: reader,
              factories: factories,
              injectables: injectables,
              moduleProvidedKeys: moduleProvidedKeys,
            );
            discoveredAsFactory = factories.length > countBefore;
          }
        } else {
          discoveredAsFactory = true;
        }
      }
    }

    if (!discoveredAsFactory) {
      _findAndAddInjectable(
        dartType: dep.type,
        reader: reader,
        injectables: injectables,
        moduleProvidedKeys: moduleProvidedKeys,
        factories: factories,
        qualifier: dep.qualifier,
      );
    }
  }
}

/// Data for a synthesized provider for a typedef function type dependency.
///
/// Generated when a factory's target class depends on a typedef'd function
/// type (e.g., `ViewModelFactory<HomePageViewModel>`). The synthesized provider
/// creates a closure that forwards function parameters and injects extra
/// constructor parameters of the return type.
typedef TypedefProviderData = ({
  /// The original FunctionType with alias (e.g., `ViewModelFactory<HomePageViewModel>`).
  DartType typedefType,

  /// The function's return type (e.g., `ViewModelBuilder<HomePageViewModel>`).
  InterfaceType returnType,

  /// The constructor of the return type used to build instances.
  ConstructorElement constructor,

  /// Parameters from the function signature, forwarded in the closure.
  List<FormalParameterElement> closureParams,

  /// Extra constructor parameters not in the function signature.
  /// Each entry contains the parameter, its resolved (substituted) type,
  /// the `@Qualifier` carried by the parameter (if any) — preserved so
  /// the binding identity stays `(type, qualifier)` across discovery,
  /// validation, and codegen — and whether to pass the provider directly
  /// (true for `Provider<T>` params) or call `.get()` (false for concrete types).
  List<({FormalParameterElement param, DartType depType, String? qualifier, bool passProvider})> injectedParams,
});

/// Discovers typedef function type dependencies from factories and creates
/// [TypedefProviderData] descriptors for code generation.
///
/// For each typedef dep, analyzes the function's return type constructor
/// to find parameters not in the function signature — these are injectable.
/// Also discovers transitive injectables from those parameters.
void discoverTypedefProviders({
  required AnnotationReader reader,
  required List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
  factories,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
  required List<TypedefProviderData> typedefProviders,
}) {
  // Use BindingKey collection here. provider.key already contains the
  // unwrapped type for async providers, which is sufficient for typedef
  // discovery that only checks raw return types.
  final moduleProvidedKeys = <BindingKey>{};
  for (final m in modules) {
    for (final ProviderDescriptor provider in m.moduleData.providers) {
      moduleProvidedKeys.add(provider.key);
    }
  }

  for (final factory in factories) {
    for (final ParameterDependency dep in factory.injectData.injectedDependencies) {
      if (dep.type is! FunctionType) continue;
      final funcType = dep.type as FunctionType;
      if (funcType.alias == null) continue;

      // Dedup by typedef type identity
      if (typedefProviders.any((t) => t.typedefType == dep.type)) continue;

      // The function's return type must be an InterfaceType with a constructor
      final DartType returnType = funcType.returnType;
      if (returnType is! InterfaceType) continue;

      final InterfaceElement classElement = returnType.element;
      if (classElement is! ClassElement) continue;

      final ConstructorElement? constructor = classElement.unnamedConstructor;
      if (constructor == null) continue;

      // Type parameter substitution map (e.g., T → HomePageViewModel)
      final List<TypeParameterElement> typeParams = classElement.typeParameters;
      final List<DartType> typeArgs = returnType.typeArguments;

      // Function params (by name) — these are forwarded in the closure
      final Set<String?> funcParamNames = funcType.formalParameters.map((p) => p.name).toSet();
      final List<FormalParameterElement> closureParams = funcType.formalParameters.toList();

      // Find "extra" constructor params — not in the function signature
      final injectedParams =
          <({FormalParameterElement param, DartType depType, String? qualifier, bool passProvider})>[];

      for (final FormalParameterElement ctorParam in constructor.formalParameters) {
        if (funcParamNames.contains(ctorParam.name)) continue;

        // Resolve type parameters in the constructor param type
        final DartType paramType = _substituteTypeArgs(ctorParam.type, typeParams, typeArgs);

        // Check if param type is Provider<X> — pass provider directly
        var passProvider = false;
        var depType = paramType;
        if (paramType is InterfaceType && paramType.element.name == 'Provider') {
          final List<DartType> providerTypeArgs = paramType.typeArguments;
          if (providerTypeArgs.length == 1) {
            depType = providerTypeArgs.first;
            passProvider = true;
          }
        }

        final String? qualifier = ctorParam.readQualifier();

        injectedParams.add((param: ctorParam, depType: depType, qualifier: qualifier, passProvider: passProvider));

        // Discover the dep type as injectable
        final BindingKey? depKey = BindingKey.fromDartType(depType, qualifier: qualifier);
        if (depKey == null || !moduleProvidedKeys.contains(depKey)) {
          _findAndAddInjectable(
            dartType: depType,
            reader: reader,
            injectables: injectables,
            moduleProvidedKeys: moduleProvidedKeys,
            factories: factories,
          );
        }
      }

      if (injectedParams.isEmpty) continue;

      typedefProviders.add((
        typedefType: dep.type,
        returnType: returnType,
        constructor: constructor,
        closureParams: closureParams,
        injectedParams: injectedParams,
      ));
    }
  }
}

/// Substitutes type parameters in [type] using the given [params] → [args] mapping.
///
/// For example, given `Provider<T>` with `params=[T]` and `args=[HomePageViewModel]`,
/// returns `Provider<HomePageViewModel>`.
DartType _substituteTypeArgs(DartType type, List<TypeParameterElement> params, List<DartType> args) {
  if (params.isEmpty || args.isEmpty) return type;

  if (type is TypeParameterType) {
    for (var i = 0; i < params.length; i++) {
      if (type.element == params[i]) {
        return args[i];
      }
    }
    return type;
  }

  if (type is InterfaceType && type.typeArguments.isNotEmpty) {
    final List<DartType> newArgs = type.typeArguments.map((a) => _substituteTypeArgs(a, params, args)).toList();
    // Only reconstruct if something changed
    for (var i = 0; i < newArgs.length; i++) {
      if (!identical(newArgs[i], type.typeArguments[i])) {
        return type.element.instantiate(typeArguments: newArgs, nullabilitySuffix: type.nullabilitySuffix);
      }
    }
  }

  return type;
}

void _findAndAddInjectable({
  required DartType dartType,
  required AnnotationReader reader,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required Set<BindingKey> moduleProvidedKeys,
  List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
      const [],
  String? qualifier,
}) {
  if (dartType case final InterfaceType interfaceType) {
    final InterfaceElement element = interfaceType.element;
    if (element case final ClassElement classElement) {
      // Skip types already discovered as assisted factories
      if (factories.any((f) => f.factoryElement == classElement)) {
        return;
      }

      List<InjectableData> newInjectables = reader.readInjectables(classElement);

      // When a specific qualifier is requested, only register the matching
      // injectable. This prevents pulling in transitive dependencies of
      // constructors that are not actually needed by the graph.
      if (qualifier != null) {
        newInjectables = newInjectables.where((i) => i.key.qualifier == qualifier).toList();
      }

      for (final injectable in newInjectables) {
        // Dedup per BindingKey — allows multiple bindings of the same class
        // with different qualifiers.
        if (injectables.any((existing) => existing.injectable.key == injectable.key)) {
          continue;
        }

        injectables.add((classElement: classElement, injectable: injectable));

        // Recursively discover dependencies
        for (final ParameterDependency dep in injectable.dependencies) {
          final BindingKey? depKey = BindingKey.fromDartType(dep.type, qualifier: dep.qualifier);
          if (depKey != null && moduleProvidedKeys.contains(depKey)) {
            continue;
          }
          _findAndAddInjectable(
            dartType: dep.type,
            reader: reader,
            injectables: injectables,
            moduleProvidedKeys: moduleProvidedKeys,
            factories: factories,
            qualifier: dep.qualifier,
          );
        }
      }
    }
  }
}
