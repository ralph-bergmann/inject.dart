import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/annotation_reader.dart';
import '../analysis/assisted_reader.dart';
import '../analysis/component_reader.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/binding_key.dart';
import '../validation/graph_validator.dart';
import 'component_generator.dart';
import 'emit_and_format.dart';
import 'listener_generator.dart';
import 'provider_generator.dart';

/// Orchestrates code generation for a single `.inject.dart` output file.
///
/// Discovers `@component`, `@module`, and `@inject` classes in a library,
/// delegates to [ComponentGenerator] and [ProviderGenerator], and produces
/// the final formatted Dart source.
class CodeGenerator {
  final _componentGen = ComponentGenerator();
  final _providerGen = ProviderGenerator();

  /// Generates the `.inject.dart` output for the given [library].
  ///
  /// Returns the formatted source string, or `null` if no `@component`
  /// class was found.
  String? generate({required LibraryElement library, required AnnotationReader reader}) {
    final String sourceUri = library.identifier;
    // Find @component class
    final List<ClassElement> componentClasses = library.classes.where((c) => reader.isComponent(c)).toList();

    if (componentClasses.isEmpty) {
      return null;
    }

    // Sort component classes alphabetically by name for determinism
    componentClasses.sort((a, b) => a.name!.compareTo(b.name!));

    final componentSpecs = <Class>[];
    final subcomponentSpecs = <Class>[];
    final factoryImplSpecs = <Class>[];
    final providerSpecs = <Class>[];
    final seenProviders = <String>{};

    for (final componentClass in componentClasses) {
      final ComponentData? componentData = reader.readComponent(componentClass);
      if (componentData == null) {
        continue;
      }

      // Namespace provider classes by their owning component whenever a file
      // declares more than one @Component — keeps single-component output
      // byte-identical while preventing name collisions across components.
      final String? componentPrefix = componentClasses.length > 1 ? componentClass.name! : null;

      // Read modules — `expandModules` follows each directly-listed module's
      // own `@Module(includes: ...)` list transitively (cycle detection +
      // dedup-by-type); see the matching comment in `inject_builder.dart`.
      final directModuleClasses = <ClassElement>[];
      for (final DartType moduleType in componentData.modules) {
        if (moduleType case InterfaceType()) {
          final InterfaceElement moduleClass = moduleType.element;
          if (moduleClass case final ClassElement classElement) {
            directModuleClasses.add(classElement);
          }
        }
      }
      final modules = reader.expandModules(directModuleClasses);

      // Discover @assistedFactory classes needed by entry points (before injectables
      // to prevent synthesized factory types from being added as injectables)
      final injectables = <({ClassElement classElement, InjectableData injectable})>[];
      final factories =
          <({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>[];
      discoverAssistedFactories(
        reader: reader,
        componentData: componentData,
        modules: modules,
        injectables: injectables,
        factories: factories,
      );

      // Discover @inject classes needed by entry points
      discoverInjectables(
        reader: reader,
        componentData: componentData,
        modules: modules,
        injectables: injectables,
        factories: factories,
      );

      // Discover typedef function type dependencies from factories
      // (e.g., ViewModelFactory<T> → synthesized closure provider)
      final typedefProviders = <TypedefProviderData>[];
      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: injectables,
        modules: modules,
        typedefProviders: typedefProviders,
      );

      final validationReporter = DiagnosticReporter();
      final graphValidator = GraphValidator(reporter: validationReporter);

      // Discover installed subcomponents and analyse their child graphs.
      final Set<BindingKey> parentProvidedKeys = collectAllProvidedKeys(
        modules: modules,
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final List<SubcomponentFactoryDescriptor> subcomponentDescriptors = discoverSubcomponentFactories(
        reader: reader,
        reporter: validationReporter,
        modules: modules,
        parentProvidedKeys: parentProvidedKeys,
      );

      graphValidator.validate(
        sourceLibrary: library,
        componentClass: componentClass,
        componentData: componentData,
        modules: modules,
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
        subcomponentDescriptors: subcomponentDescriptors,
      );
      final Map<BindingKey, bool> asyncBindings = graphValidator.asyncBindings;
      final Map<ClassElement, SubcomponentValidationResult> subcomponentResults =
          graphValidator.lastSubcomponentResults;

      // Parent providers consumed by any installed subcomponent become fields.
      final promoteToFields = <BindingKey>{
        for (final result in subcomponentResults.values) ...result.graphResult.parentBindingsUsed,
      };
      final subcomponentFactoryBindings = <({BindingKey key, ClassElement factoryClass})>[
        for (final descriptor in subcomponentDescriptors)
          (key: descriptor.factoryBindingKey, factoryClass: descriptor.factoryClass),
      ];
      final effectiveModuleProviders = <BindingKey, ({ClassElement moduleClass, ProviderDescriptor descriptor})>{};
      for (final m in modules) {
        for (final ProviderDescriptor provider in m.moduleData.providers) {
          effectiveModuleProviders[provider.key] = (moduleClass: m.moduleClass, descriptor: provider);
        }
      }

      // Partition listener providers: collect from sorted modules in
      // deterministic order. All registered listeners participate in chaining.
      final sortedModules = [...modules]..sort((a, b) => a.moduleClass.name!.compareTo(b.moduleClass.name!));
      final listenerProviders = <({ClassElement moduleClass, ProviderDescriptor descriptor})>[];
      for (final m in sortedModules) {
        for (final ProviderDescriptor provider in m.moduleData.providers) {
          if (provider.metadata.isProvisionListener) {
            listenerProviders.add((moduleClass: m.moduleClass, descriptor: provider));
          }
        }
      }

      // Generate provider classes (deduplicate by name)
      // Must happen before component generation to populate listenerCallsPerBinding.
      final listenerCallsPerBinding = <BindingKey, List<ListenerCallInfo>>{};

      for (final ({ProviderDescriptor descriptor, ClassElement moduleClass}) entry in effectiveModuleProviders.values) {
        final DartType returnType = entry.descriptor.returnType;
        final DartType provisionedType = entry.descriptor.metadata.isAsynchronous
            ? returnType.unwrapFuture
            : returnType;
        // Listener providers never receive listener calls — prevents
        // cycles and keeps listeners separate from real deps.
        final List<ListenerCallInfo> listenerCalls = entry.descriptor.metadata.isProvisionListener
            ? <ListenerCallInfo>[]
            : ListenerGenerator.matchingListeners(
                provisionedType: provisionedType,
                listenerProviders: listenerProviders,
                selfKey: entry.descriptor.key,
                componentPrefix: componentPrefix,
              );
        if (listenerCalls.isNotEmpty) {
          listenerCallsPerBinding[entry.descriptor.key] = listenerCalls;
        }
        final Class spec = _providerGen.generateModuleProvider(
          descriptor: entry.descriptor,
          moduleClass: entry.moduleClass,
          isAsynchronous: asyncBindings[entry.descriptor.key] == true,
          asyncBindings: asyncBindings,
          listenerCalls: listenerCalls,
          componentPrefix: componentPrefix,
          sourceUri: sourceUri,
        );
        if (seenProviders.add(spec.name)) {
          providerSpecs.add(spec);
        }
      }

      for (final injectable in injectables) {
        final List<ListenerCallInfo> listenerCalls = ListenerGenerator.matchingListeners(
          provisionedType: injectable.classElement.thisType,
          listenerProviders: listenerProviders,
          selfKey: injectable.injectable.key,
          componentPrefix: componentPrefix,
        );
        if (listenerCalls.isNotEmpty) {
          listenerCallsPerBinding[injectable.injectable.key] = listenerCalls;
        }
        final Class spec = _providerGen.generateInjectProvider(
          classElement: injectable.classElement,
          injectable: injectable.injectable,
          isAsynchronous: asyncBindings[injectable.injectable.key] == true,
          asyncBindings: asyncBindings,
          listenerCalls: listenerCalls,
          componentPrefix: componentPrefix,
          sourceUri: sourceUri,
        );
        if (seenProviders.add(spec.name)) {
          providerSpecs.add(spec);
        }
      }

      // Group factories by factoryElement for multi-method inline factory generation.
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
        final Class providerSpec = _providerGen.generateFactoryProvider(
          factoryElement: group.first.factoryElement,
          injectDataList: [for (final f in group) f.injectData],
          componentPrefix: componentPrefix,
          sourceUri: sourceUri,
        );
        if (seenProviders.add(providerSpec.name)) {
          providerSpecs.add(providerSpec);
        }

        final Class inlineFactorySpec = _providerGen.generateInlineFactory(
          factoryElement: group.first.factoryElement,
          entries: [for (final f in group) (injectData: f.injectData, factoryData: f.factoryData)],
          componentPrefix: componentPrefix,
          sourceUri: sourceUri,
        );
        if (seenProviders.add(inlineFactorySpec.name)) {
          providerSpecs.add(inlineFactorySpec);
        }
      }

      for (final typedefData in typedefProviders) {
        final Class spec = _providerGen.generateTypedefProvider(
          typedefData: typedefData,
          componentPrefix: componentPrefix,
          sourceUri: sourceUri,
        );
        if (seenProviders.add(spec.name)) {
          providerSpecs.add(spec);
        }
      }

      // Generate component class (after providers to use listenerCallsPerBinding)
      componentSpecs.add(
        _componentGen.generate(
          componentClass: componentClass,
          componentData: componentData,
          modules: modules,
          injectables: injectables,
          factories: factories,
          typedefProviders: typedefProviders,
          asyncBindings: asyncBindings,
          listenerProviders: listenerProviders,
          listenerCallsPerBinding: listenerCallsPerBinding,
          componentPrefix: componentPrefix,
          subcomponentFactoryBindings: subcomponentFactoryBindings,
          promoteToFields: promoteToFields,
          sourceUri: sourceUri,
        ),
      );

      // Generate the subcomponent classes, factory implementations, factory
      // providers, and child-graph providers for every installed subcomponent.
      if (subcomponentDescriptors.isNotEmpty) {
        final String parentClassName = '${componentClass.name!}\$Component';
        final Map<BindingKey, String> parentProviderFieldNames = _componentGen.providerFieldNames(
          modules: modules,
          injectables: injectables,
          factories: factories,
          typedefProviders: typedefProviders,
          subcomponentFactoryBindings: subcomponentFactoryBindings,
          componentPrefix: componentPrefix,
        );

        for (final descriptor in subcomponentDescriptors) {
          final SubcomponentValidationResult? childResult = subcomponentResults[descriptor.subcomponentClass];
          if (childResult == null) {
            continue;
          }
          _generateSubcomponentOutput(
            descriptor: descriptor,
            childResult: childResult,
            parentClassName: parentClassName,
            parentPrefix: componentPrefix,
            parentProviderFieldNames: parentProviderFieldNames,
            subcomponentSpecs: subcomponentSpecs,
            factoryImplSpecs: factoryImplSpecs,
            providerSpecs: providerSpecs,
            seenProviders: seenProviders,
            sourceUri: sourceUri,
          );
        }
      }
    }

    if (componentSpecs.isEmpty) {
      return null;
    }

    // Sort provider classes alphabetically by name for determinism
    providerSpecs.sort((a, b) => a.name.compareTo(b.name));

    // Sort subcomponent and factory-impl classes alphabetically for determinism
    subcomponentSpecs.sort((a, b) => a.name.compareTo(b.name));
    factoryImplSpecs.sort((a, b) => a.name.compareTo(b.name));

    // Build library: component classes first (sorted), then subcomponent
    // classes, then subcomponent factory implementations, then sorted providers
    final librarySpec = Library(
      (b) => b
        ..body.addAll(componentSpecs)
        ..body.addAll(subcomponentSpecs)
        ..body.addAll(factoryImplSpecs)
        ..body.addAll(providerSpecs),
    );

    // Emit and format
    return emitAndFormat(librarySpec);
  }

  /// Generates all output for one installed subcomponent: its child-graph
  /// provider classes, the `<Name>$Subcomponent` class, the private factory
  /// implementation, and the factory provider bound in the parent graph.
  void _generateSubcomponentOutput({
    required SubcomponentFactoryDescriptor descriptor,
    required SubcomponentValidationResult childResult,
    required String parentClassName,
    required String? parentPrefix,
    required Map<BindingKey, String> parentProviderFieldNames,
    required List<Class> subcomponentSpecs,
    required List<Class> factoryImplSpecs,
    required List<Class> providerSpecs,
    required Set<String> seenProviders,
    required String? sourceUri,
  }) {
    // Child-graph providers are namespaced by the subcomponent's own name,
    // AND by the parent's name whenever this file declares more than one
    // `@Component` (`parentPrefix != null`). The parent-name segment matters
    // when two different components in the same file each install the same
    // `@subcomponent` class: without it, both installations would compute
    // the same provider class names even though they belong to distinct
    // parent graphs, colliding — the second installation's providers would
    // be silently dropped by the `seenProviders` dedup below, leaving the
    // second `<Name>$Subcomponent` wired to providers built for the first
    // parent's type. This must stay in sync with `ComponentGenerator
    // .generateSubcomponent`'s own `componentPrefix`, which computes the
    // identical value for the field-type references it emits.
    final String childPrefix = parentPrefix != null
        ? '$parentPrefix\$${descriptor.subcomponentClass.name!}'
        : descriptor.subcomponentClass.name!;
    final Set<BindingKey> parentKeys = childResult.graphResult.parentBindingsUsed;
    final Map<BindingKey, bool> asyncBindings = childResult.asyncResult.asyncBindings;
    final List<({ClassElement moduleClass, ModuleData moduleData})> modules = descriptor.subcomponentModules;

    final effectiveModuleProviders = <BindingKey, ({ClassElement moduleClass, ProviderDescriptor descriptor})>{};
    for (final m in modules) {
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        effectiveModuleProviders[provider.key] = (moduleClass: m.moduleClass, descriptor: provider);
      }
    }

    final sortedModules = [...modules]..sort((a, b) => a.moduleClass.name!.compareTo(b.moduleClass.name!));
    final listenerProviders = <({ClassElement moduleClass, ProviderDescriptor descriptor})>[];
    for (final m in sortedModules) {
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        if (provider.metadata.isProvisionListener) {
          listenerProviders.add((moduleClass: m.moduleClass, descriptor: provider));
        }
      }
    }

    final listenerCallsPerBinding = <BindingKey, List<ListenerCallInfo>>{};

    for (final ({ProviderDescriptor descriptor, ClassElement moduleClass}) entry in effectiveModuleProviders.values) {
      final DartType returnType = entry.descriptor.returnType;
      final DartType provisionedType = entry.descriptor.metadata.isAsynchronous ? returnType.unwrapFuture : returnType;
      final List<ListenerCallInfo> listenerCalls = entry.descriptor.metadata.isProvisionListener
          ? <ListenerCallInfo>[]
          : ListenerGenerator.matchingListeners(
              provisionedType: provisionedType,
              listenerProviders: listenerProviders,
              selfKey: entry.descriptor.key,
              componentPrefix: childPrefix,
            );
      if (listenerCalls.isNotEmpty) {
        listenerCallsPerBinding[entry.descriptor.key] = listenerCalls;
      }
      final Class spec = _providerGen.generateModuleProvider(
        descriptor: entry.descriptor,
        moduleClass: entry.moduleClass,
        isAsynchronous: asyncBindings[entry.descriptor.key] == true,
        asyncBindings: asyncBindings,
        listenerCalls: listenerCalls,
        componentPrefix: childPrefix,
        parentKeys: parentKeys,
        parentPrefix: parentPrefix,
        sourceUri: sourceUri,
      );
      if (seenProviders.add(spec.name)) {
        providerSpecs.add(spec);
      }
    }

    for (final injectable in descriptor.subcomponentInjectables) {
      final List<ListenerCallInfo> listenerCalls = ListenerGenerator.matchingListeners(
        provisionedType: injectable.classElement.thisType,
        listenerProviders: listenerProviders,
        selfKey: injectable.injectable.key,
        componentPrefix: childPrefix,
      );
      if (listenerCalls.isNotEmpty) {
        listenerCallsPerBinding[injectable.injectable.key] = listenerCalls;
      }
      final Class spec = _providerGen.generateInjectProvider(
        classElement: injectable.classElement,
        injectable: injectable.injectable,
        isAsynchronous: asyncBindings[injectable.injectable.key] == true,
        asyncBindings: asyncBindings,
        listenerCalls: listenerCalls,
        componentPrefix: childPrefix,
        parentKeys: parentKeys,
        parentPrefix: parentPrefix,
        sourceUri: sourceUri,
      );
      if (seenProviders.add(spec.name)) {
        providerSpecs.add(spec);
      }
    }

    final factoriesByElement =
        <
          ClassElement,
          List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
        >{};
    for (final factory in descriptor.subcomponentFactories) {
      (factoriesByElement[factory.factoryElement] ??= []).add(factory);
    }

    for (final List<({AssistedFactoryData factoryData, ClassElement factoryElement, AssistedInjectData injectData})>
        group
        in factoriesByElement.values) {
      final Class providerSpec = _providerGen.generateFactoryProvider(
        factoryElement: group.first.factoryElement,
        injectDataList: [for (final f in group) f.injectData],
        componentPrefix: childPrefix,
        parentKeys: parentKeys,
        parentPrefix: parentPrefix,
        sourceUri: sourceUri,
      );
      if (seenProviders.add(providerSpec.name)) {
        providerSpecs.add(providerSpec);
      }

      final Class inlineFactorySpec = _providerGen.generateInlineFactory(
        factoryElement: group.first.factoryElement,
        entries: [for (final f in group) (injectData: f.injectData, factoryData: f.factoryData)],
        componentPrefix: childPrefix,
        parentKeys: parentKeys,
        parentPrefix: parentPrefix,
        sourceUri: sourceUri,
      );
      if (seenProviders.add(inlineFactorySpec.name)) {
        providerSpecs.add(inlineFactorySpec);
      }
    }

    for (final typedefData in descriptor.subcomponentTypedefProviders) {
      final Class spec = _providerGen.generateTypedefProvider(
        typedefData: typedefData,
        componentPrefix: childPrefix,
        parentKeys: parentKeys,
        parentPrefix: parentPrefix,
        sourceUri: sourceUri,
      );
      if (seenProviders.add(spec.name)) {
        providerSpecs.add(spec);
      }
    }

    // `@subcomponentFactory` value parameters (Dagger's `@BindsInstance`
    // equivalent) — each gets a trivial provider wrapping the raw value so it
    // participates in the ordinary dependency-resolution machinery.
    for (final valueParameter in descriptor.valueParameters) {
      final Class spec = _providerGen.generateValueParameterProvider(
        type: valueParameter.parameter.type,
        qualifier: valueParameter.key.qualifier,
        componentPrefix: childPrefix,
        sourceUri: sourceUri,
      );
      if (seenProviders.add(spec.name)) {
        providerSpecs.add(spec);
      }
    }

    subcomponentSpecs.add(
      _componentGen.generateSubcomponent(
        subcomponentClass: descriptor.subcomponentClass,
        subcomponentData: descriptor.subcomponentData,
        parentClassName: parentClassName,
        parentProviderFieldNames: parentProviderFieldNames,
        modules: modules,
        injectables: descriptor.subcomponentInjectables,
        factories: descriptor.subcomponentFactories,
        typedefProviders: descriptor.subcomponentTypedefProviders,
        asyncBindings: asyncBindings,
        listenerProviders: listenerProviders,
        listenerCallsPerBinding: listenerCallsPerBinding,
        valueParameters: descriptor.valueParameters,
        parentPrefix: parentPrefix,
        sourceUri: sourceUri,
      ),
    );

    final explicitFactory = descriptor.explicitFactory;
    factoryImplSpecs.add(
      explicitFactory != null
          ? _componentGen.generateExplicitSubcomponentFactoryImpl(
              explicitFactoryData: explicitFactory,
              subcomponentClass: descriptor.subcomponentClass,
              parentClassName: parentClassName,
              parentPrefix: parentPrefix,
              sourceUri: sourceUri,
            )
          : _componentGen.generateSubcomponentFactoryImpl(
              factoryClass: descriptor.factoryClass,
              subcomponentClass: descriptor.subcomponentClass,
              parentClassName: parentClassName,
              modules: modules,
              parentPrefix: parentPrefix,
              sourceUri: sourceUri,
            ),
    );

    final Class factoryProviderSpec = _providerGen.generateSubcomponentFactoryProvider(
      factoryClass: descriptor.factoryClass,
      parentClassName: parentClassName,
      componentPrefix: parentPrefix,
      sourceUri: sourceUri,
    );
    if (seenProviders.add(factoryProviderSpec.name)) {
      providerSpecs.add(factoryProviderSpec);
    }
  }
}
