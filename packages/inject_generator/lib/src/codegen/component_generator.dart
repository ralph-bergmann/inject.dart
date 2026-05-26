import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/assisted_reader.dart';
import '../analysis/component_reader.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../extensions/string_extensions.dart';
import '../validation/binding_key.dart';
import 'listener_generator.dart';
import 'provider_generator.dart';

/// Generates `ComponentName$Component` classes implementing the
/// abstract component interface.
///
/// The component class wires all providers together in its constructor
/// and exposes entry points as overridden getters/methods.
class ComponentGenerator {
  /// Generates a `$Component` class.
  ///
  /// [modules] provides the module ClassElements paired with their read data.
  /// [injectables] provides the injectable ClassElements paired with their data.
  Class generate({
    required ClassElement componentClass,
    required ComponentData componentData,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
        const [],
    List<TypedefProviderData> typedefProviders = const [],
    Map<BindingKey, bool> asyncBindings = const {},
    List<({ClassElement moduleClass, ProviderDescriptor descriptor})> listenerProviders = const [],
    Map<BindingKey, List<ListenerCallInfo>> listenerCallsPerBinding = const {},
    String? sourceUri,
  }) {
    final String componentName = componentClass.name!;
    final className = '$componentName\$Component';
    final Reference componentTypeRef = refer(componentName, componentClass.resolvePublicUri(sourceUri: sourceUri));

    // Build binding registry
    final List<_Binding> bindings = _buildBindings(modules, injectables, factories, typedefProviders, asyncBindings);

    // Add listener providers as implicit dependencies for topological ordering
    for (final MapEntry<BindingKey, List<ListenerCallInfo>> entry in listenerCallsPerBinding.entries) {
      final _Binding? binding = bindings.where((b) => b.key == entry.key).firstOrNull;
      if (binding == null) continue;
      for (final ListenerCallInfo listener in entry.value) {
        final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
        final _Binding? listenerBinding = bindings.where((b) => b.baseName == listenerBaseName).firstOrNull;
        if (listenerBinding != null && !binding.dependencyKeys.contains(listenerBinding.key)) {
          binding.dependencyKeys.add(listenerBinding.key);
        }
      }
    }

    // Nullable-widening: normalize dep keys — replace `Foo?` with `Foo` when
    // no exact nullable binding exists but a non-nullable one does.
    // Runs after listener insertion so listener-added keys are covered.
    final Set<BindingKey> bindingKeys = {for (final b in bindings) b.key};
    for (final binding in bindings) {
      for (var i = 0; i < binding.dependencyKeys.length; i++) {
        final BindingKey key = binding.dependencyKeys[i];
        if (key.isNullable) {
          final BindingKey nonNullableKey = key.nonNullable;
          if (!bindingKeys.contains(key) && bindingKeys.contains(nonNullableKey)) {
            binding.dependencyKeys[i] = nonNullableKey;
          }
        }
      }
    }

    // Match entry points to bindings
    _matchEntryPoints(bindings, componentData.entryPoints);

    // Topological sort
    final List<_Binding> sorted = _topologicalSort(bindings);

    // Module parameter names: uncapitalized class name, preserving declaration
    // order from @Component([...]) — later modules can override earlier ones.
    final moduleParams = <({ClassElement moduleClass, String paramName, bool hasDefaultConstructor})>[];
    for (final m in modules) {
      final String name = m.moduleClass.name!.uncapitalize;
      moduleParams.add((
        moduleClass: m.moduleClass,
        paramName: name,
        hasDefaultConstructor: m.moduleData.hasDefaultConstructor,
      ));
    }

    // Generate factory constructor
    final Constructor factoryConstructor = _buildFactory(
      className: className,
      moduleParams: moduleParams,
      sourceUri: sourceUri,
    );

    // Generate private constructor — does not need the default-ctor flag.
    final Constructor privateConstructor = _buildPrivateConstructor(
      moduleParams: [
        for (final mp in moduleParams) (moduleClass: mp.moduleClass, paramName: mp.paramName),
      ],
      sortedBindings: sorted,
      listenerCallsPerBinding: listenerCallsPerBinding,
      sourceUri: sourceUri,
    );

    // Generate late final fields for entry-point providers
    final entryFields = <Field>[];
    for (final binding in sorted) {
      if (binding.isEntryPoint) {
        entryFields.add(
          Field(
            (b) => b
              ..name = '_${binding.baseName}'
              ..type = refer(binding.providerClassName)
              ..late = true
              ..modifier = FieldModifier.final$,
          ),
        );
      }
    }

    // Generate entry-point overrides
    final entryMethods = <Method>[];
    for (final binding in sorted) {
      if (!binding.isEntryPoint) {
        continue;
      }
      for (final EntryPoint ep in binding.entryPoints) {
        final Element element = ep.element;
        final DartType? returnType = element.entryPointReturnType;
        final String? name = element.entryPointName;
        if (returnType == null || name == null) {
          continue;
        }

        final bodyExpr = ep.isProvider ? '_${binding.baseName}' : '_${binding.baseName}.get()';

        entryMethods.add(
          Method(
            (b) => b
              ..name = name
              ..returns = returnType.typeRef(sourceUri: sourceUri)
              ..annotations.add(refer('override'))
              ..lambda = true
              ..body = Code(bodyExpr)
              ..type = element is PropertyAccessorElement ? MethodType.getter : null,
          ),
        );
      }
    }

    return Class(
      (b) => b
        ..name = className
        ..implements.add(componentTypeRef)
        ..constructors.addAll([factoryConstructor, privateConstructor])
        ..fields.addAll(entryFields)
        ..methods.addAll(entryMethods),
    );
  }

  // --- Factory constructor ---

  Constructor _buildFactory({
    required String className,
    required List<({ClassElement moduleClass, String paramName, bool hasDefaultConstructor})> moduleParams,
    String? sourceUri,
  }) {
    final params = <Parameter>[];
    final args = <Expression>[];

    for (final mp in moduleParams) {
      final Reference moduleTypeRef = refer(
        mp.moduleClass.name!,
        mp.moduleClass.resolvePublicUri(sourceUri: sourceUri),
      );
      final bool hasDefaultCtor = mp.hasDefaultConstructor;
      params.add(
        Parameter(
          (b) => b
            ..name = mp.paramName
            ..named = true
            ..required = !hasDefaultCtor
            ..type = TypeReference(
              (b) => b
                ..symbol = moduleTypeRef.symbol
                ..url = moduleTypeRef.url
                ..isNullable = hasDefaultCtor,
            ),
        ),
      );
      final Expression arg = hasDefaultCtor
          ? refer(mp.paramName).ifNullThen(moduleTypeRef.newInstance([]))
          : refer(mp.paramName);
      args.add(arg);
    }

    return Constructor(
      (b) => b
        ..factory = true
        ..name = 'create'
        ..optionalParameters.addAll(params)
        ..lambda = true
        ..body = refer(className).newInstanceNamed('_', args).code,
    );
  }

  // --- Private constructor ---

  Constructor _buildPrivateConstructor({
    required List<({ClassElement moduleClass, String paramName})> moduleParams,
    required List<_Binding> sortedBindings,
    Map<BindingKey, List<ListenerCallInfo>> listenerCallsPerBinding = const {},
    String? sourceUri,
  }) {
    final params = <Parameter>[];
    for (final mp in moduleParams) {
      final Reference moduleTypeRef = refer(
        mp.moduleClass.name!,
        mp.moduleClass.resolvePublicUri(sourceUri: sourceUri),
      );
      params.add(
        Parameter(
          (b) => b
            ..name = mp.paramName
            ..type = moduleTypeRef,
        ),
      );
    }

    // Build body: instantiate providers in topological order
    final bodyStatements = <String>[];
    for (final binding in sortedBindings) {
      final ctorArgs = <String>[];

      // Collect listener binding keys for this binding to exclude from regular deps
      final List<ListenerCallInfo>? listenerCalls = listenerCallsPerBinding[binding.key];
      final listenerBindingKeys = <BindingKey>{};
      if (listenerCalls != null) {
        for (final ListenerCallInfo listener in listenerCalls) {
          final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
          final _Binding listenerBinding = sortedBindings.firstWhere((b) => b.baseName == listenerBaseName);
          listenerBindingKeys.add(listenerBinding.key);
        }
      }

      // Dependency providers first (excluding listener deps added for topo sort)
      for (final BindingKey depKey in binding.dependencyKeys) {
        if (listenerBindingKeys.contains(depKey)) continue;
        final _Binding depBinding = sortedBindings.firstWhere((b) => b.key == depKey);
        ctorArgs.add(depBinding.isEntryPoint ? '_${depBinding.baseName}' : depBinding.variableName);
      }

      // Listener provider refs between deps and module
      if (listenerCalls != null) {
        for (final ListenerCallInfo listener in listenerCalls) {
          final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
          final _Binding listenerBinding = sortedBindings.firstWhere((b) => b.baseName == listenerBaseName);
          ctorArgs.add(listenerBinding.isEntryPoint ? '_${listenerBinding.baseName}' : listenerBinding.variableName);
        }
      }

      // Module instance last (for module providers)
      if (binding.moduleParamName != null) {
        ctorArgs.add(binding.moduleParamName!);
      }

      final String argsStr = ctorArgs.join(', ');

      if (binding.isEntryPoint) {
        bodyStatements.add('_${binding.baseName} = ${binding.providerClassName}($argsStr);');
      } else {
        bodyStatements.add('final ${binding.variableName} = ${binding.providerClassName}($argsStr);');
      }
    }

    return Constructor(
      (b) => b
        ..name = '_'
        ..requiredParameters.addAll(params)
        ..body = Code(bodyStatements.join('\n')),
    );
  }

  // --- Binding resolution ---

  List<_Binding> _buildBindings(
    List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories,
    List<TypedefProviderData> typedefProviders,
    Map<BindingKey, bool> asyncBindings,
  ) {
    final bindings = <_Binding>[];

    // NOTE: order-sensitive — later modules override earlier ones (mock-injection pattern). Do not sort or reorder.
    for (final m in modules) {
      final String moduleParamName = m.moduleClass.name!.uncapitalize;
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        final DartType returnType = provider.returnType;
        // For @asynchronous Future<T> providers, use T for naming so
        // the provider class name matches consumer dep references.
        final DartType unwrapped = returnType.unwrapFuture;
        final String typeName = provider.metadata.isAsynchronous && !identical(unwrapped, returnType)
            ? unwrapped.displayName
            : returnType.displayName;
        bindings
          ..removeWhere((binding) => binding.key == provider.key)
          ..add(
            _Binding(
              key: provider.key,
              typeName: typeName,
              qualifier: provider.key.qualifier,
              moduleParamName: moduleParamName,
              dependencyKeys: provider.dependencies
                  .map((dep) => _requireBindingKey(dep.type, qualifier: dep.qualifier))
                  .toList(),
              isSingleton: provider.metadata.isSingleton || provider.metadata.isProvisionListener,
              isAsynchronous: asyncBindings[provider.key] == true,
            ),
          );
      }
    }

    for (final injectable in injectables) {
      final String typeName = injectable.classElement.name!;
      bindings.add(
        _Binding(
          key: injectable.injectable.key,
          typeName: typeName,
          qualifier: injectable.injectable.key.qualifier,
          moduleParamName: null,
          dependencyKeys: injectable.injectable.dependencies
              .map((dep) => _requireBindingKey(dep.type, qualifier: dep.qualifier))
              .toList(),
          isSingleton: injectable.injectable.isSingleton,
          isAsynchronous: asyncBindings[injectable.injectable.key] == true,
        ),
      );
    }

    // Group factories by factoryElement so multi-constructor factories
    // produce a single binding with unified dependency keys.
    final factoriesByElement =
        <
          ClassElement,
          List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
        >{};
    for (final factory in factories) {
      (factoriesByElement[factory.factoryElement] ??= []).add(factory);
    }

    for (final List<({AssistedFactoryData factoryData, ClassElement factoryElement, AssistedInjectData injectData})>
        group
        in factoriesByElement.values) {
      final String typeName = group.first.factoryElement.name!;
      final BindingKey? key = BindingKey.fromDartType(group.first.factoryElement.thisType);
      if (key == null) {
        continue;
      }

      // Unify dependency keys across all constructors (deduplicate)
      final depKeys = <BindingKey>{};
      for (final factory in group) {
        for (final ParameterDependency dep in factory.injectData.injectedDependencies) {
          depKeys.add(_requireBindingKey(dep.type, qualifier: dep.qualifier));
        }
      }

      bindings.add(
        _Binding(
          key: key,
          typeName: typeName,
          qualifier: null,
          moduleParamName: null,
          dependencyKeys: depKeys.toList(),
          isSingleton: false,
          isAsynchronous: asyncBindings[key] == true,
        ),
      );
    }

    for (final typedefData in typedefProviders) {
      final DartType typedefType = typedefData.typedefType;
      final BindingKey? key = BindingKey.fromDartType(typedefType);
      if (key == null) {
        continue;
      }
      final String typeName = typedefType.displayName;
      bindings.add(
        _Binding(
          key: key,
          typeName: typeName,
          qualifier: null,
          moduleParamName: null,
          dependencyKeys: typedefData.injectedParams
              .map((ip) => _requireBindingKey(ip.depType, qualifier: ip.qualifier))
              .toList(),
          isSingleton: false,
          isAsynchronous: asyncBindings[key] == true,
        ),
      );
    }

    return bindings;
  }

  void _matchEntryPoints(List<_Binding> bindings, List<EntryPoint> entryPoints) {
    for (final ep in entryPoints) {
      for (final binding in bindings) {
        if (binding.key == ep.key) {
          binding.entryPoints.add(ep);
          break;
        }
      }
    }
  }

  List<_Binding> _topologicalSort(List<_Binding> bindings) {
    // Sort by typeName for determinism before topological sort
    final sorted = <_Binding>[];
    final visited = <BindingKey>{};

    void visit(_Binding binding) {
      if (visited.contains(binding.key)) {
        return;
      }
      visited.add(binding.key);
      for (final BindingKey depKey in binding.dependencyKeys) {
        final _Binding? dep = bindings.where((b) => b.key == depKey).firstOrNull;
        if (dep != null) {
          visit(dep);
        }
      }
      sorted.add(binding);
    }

    // Process in alphabetical order for determinism
    ([...bindings]..sort((a, b) {
          final int cmp = a.typeName.compareTo(b.typeName);
          if (cmp != 0) return cmp;
          // Tiebreaker: sort by qualifier so that multiple bindings of the
          // same type produce a deterministic order.
          return (a.qualifier ?? '').compareTo(b.qualifier ?? '');
        }))
        .forEach(visit);

    return sorted;
  }

  // --- Helpers ---

  static BindingKey _requireBindingKey(DartType dartType, {String? qualifier}) {
    final BindingKey? key = BindingKey.fromDartType(dartType, qualifier: qualifier);
    if (key != null) {
      return key;
    }
    throw StateError('Unsupported binding type in component generation: ${dartType.getDisplayString()}');
  }
}

// --- Internal data types ---

class _Binding {
  _Binding({
    required this.key,
    required this.typeName,
    required this.qualifier,
    required this.moduleParamName,
    required this.dependencyKeys,
    required this.isSingleton,
    required this.isAsynchronous,
  });

  final BindingKey key;
  final String typeName;
  final String? qualifier;
  final String? moduleParamName;
  final List<BindingKey> dependencyKeys;
  final bool isSingleton;
  final bool isAsynchronous;

  final List<EntryPoint> entryPoints = [];

  bool get isEntryPoint => entryPoints.isNotEmpty;

  String get providerClassName => ProviderGenerator.providerClassName(typeName, qualifier);

  String get baseName => ProviderGenerator.providerBaseName(typeName, qualifier);

  /// Variable name used in the component constructor (no underscore for locals).
  String get variableName => baseName;
}
