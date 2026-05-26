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
    final providerSpecs = <Class>[];
    final seenProviders = <String>{};

    for (final componentClass in componentClasses) {
      final ComponentData? componentData = reader.readComponent(componentClass);
      if (componentData == null) {
        continue;
      }

      // Read modules
      final modules = <({ClassElement moduleClass, ModuleData moduleData})>[];
      for (final DartType moduleType in componentData.modules) {
        if (moduleType case InterfaceType()) {
          final InterfaceElement moduleClass = moduleType.element;
          if (moduleClass case final ClassElement classElement) {
            final ModuleData moduleData = reader.readModule(classElement);
            modules.add((moduleClass: classElement, moduleData: moduleData));
          }
        }
      }

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
      graphValidator.validate(
        sourceLibrary: library,
        componentClass: componentClass,
        componentData: componentData,
        modules: modules,
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final Map<BindingKey, bool> asyncBindings = graphValidator.asyncBindings;
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
          sourceUri: sourceUri,
        );
        if (seenProviders.add(providerSpec.name)) {
          providerSpecs.add(providerSpec);
        }

        final Class inlineFactorySpec = _providerGen.generateInlineFactory(
          factoryElement: group.first.factoryElement,
          entries: [for (final f in group) (injectData: f.injectData, factoryData: f.factoryData)],
          sourceUri: sourceUri,
        );
        if (seenProviders.add(inlineFactorySpec.name)) {
          providerSpecs.add(inlineFactorySpec);
        }
      }

      for (final typedefData in typedefProviders) {
        final Class spec = _providerGen.generateTypedefProvider(typedefData: typedefData, sourceUri: sourceUri);
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
          sourceUri: sourceUri,
        ),
      );
    }

    if (componentSpecs.isEmpty) {
      return null;
    }

    // Sort provider classes alphabetically by name for determinism
    providerSpecs.sort((a, b) => a.name.compareTo(b.name));

    // Build library: component classes first (sorted), then sorted providers
    final librarySpec = Library(
      (b) => b
        ..body.addAll(componentSpecs)
        ..body.addAll(providerSpecs),
    );

    // Emit and format
    return emitAndFormat(librarySpec);
  }
}
