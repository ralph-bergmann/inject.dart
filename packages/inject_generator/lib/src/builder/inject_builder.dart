import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

import '../analysis/annotation_reader.dart';
import '../analysis/assisted_reader.dart';
import '../analysis/component_reader.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../codegen/code_generator.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/async_propagation_result.dart';
import '../validation/binding_graph_result.dart';
import '../validation/graph_printer.dart';
import '../validation/graph_validator.dart';
import 'inject_builder_options.dart';

/// Builder entry point for `.inject.dart` generation.
///
/// Orchestrates the three-phase pipeline (analysis → validation → codegen)
/// within a single `build_runner` pass. Each invocation of [generate] creates
/// a fresh [DiagnosticReporter] and runs all phases in memory — no
/// `summary.json` or multi-pass workarounds.
class InjectBuilder extends Generator {
  /// Creates an [InjectBuilder] with the given [options].
  ///
  /// [debugPrint] overrides the sink used for `debug_graph` output (tests).
  InjectBuilder({
    this.options = InjectBuilderOptions.defaults,
    void Function(String)? debugPrint,
  }) : _debugPrint = debugPrint ?? _defaultPrint;

  static void _defaultPrint(String message) => print(message);

  /// Parsed `inject_builder` options from `build.yaml`.
  final InjectBuilderOptions options;
  final void Function(String) _debugPrint;

  /// Creates a fresh [DiagnosticReporter] for each [generate] invocation.
  ///
  /// Override in a subclass (in tests) to inject a pre-populated reporter
  /// and exercise the error-suppression or warning paths without needing
  /// real analysis/validation phase implementations.
  @visibleForTesting
  DiagnosticReporter createReporter() => DiagnosticReporter();

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    final DiagnosticReporter reporter = createReporter();
    final reader = AnnotationReader(reporter: reporter);
    final LibraryElement libraryElement = library.element;

    // Phase 1 & 2: Analysis + Validation per component
    final validator = GraphValidator(reporter: reporter);

    final List<ClassElement> componentClasses = libraryElement.classes.where(reader.isComponent).toList();

    // Collect per-component debug data only when the debug pass is enabled.
    List<
        ({
          ClassElement componentClass,
          List<EntryPoint> entryPoints,
          BindingGraphResult graphResult,
          AsyncPropagationResult asyncResult
        })>? debugEntries;

    for (final componentClass in componentClasses) {
      final ComponentData? componentData = reader.readComponent(componentClass);
      if (componentData == null) {
        continue;
      }

      // Read modules
      final modules = <({ClassElement moduleClass, ModuleData moduleData})>[];
      for (final DartType moduleType in componentData.modules) {
        if (moduleType case InterfaceType()) {
          final InterfaceElement moduleElement = moduleType.element;
          if (moduleElement case final ClassElement classElement) {
            final ModuleData moduleData = reader.readModule(classElement);
            modules.add((moduleClass: classElement, moduleData: moduleData));
          } else {
            reporter.errorForElement(
              componentClass,
              message:
                  "Module '${moduleType.getDisplayString()}' in @Component is not a class — "
                  '@module requires a class declaration (not a mixin, enum, or extension type).',
              suggestion: 'Change the @module declaration to a class, or remove it from @Component.',
            );
          }
        } else {
          reporter.errorForElement(
            componentClass,
            message:
                "Module '${moduleType.getDisplayString()}' in @Component is not a valid type — "
                '@module requires a class declaration.',
          );
        }
      }

      // Discover assisted factories from entry points (before injectables
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

      // Discover injectables from entry points
      discoverInjectables(
        reader: reader,
        componentData: componentData,
        modules: modules,
        injectables: injectables,
        factories: factories,
      );

      // Discover typedef function type dependencies from factories
      final typedefProviders = <TypedefProviderData>[];
      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: injectables,
        modules: modules,
        typedefProviders: typedefProviders,
      );

      validator.validate(
        sourceLibrary: libraryElement,
        componentClass: componentClass,
        componentData: componentData,
        modules: modules,
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
        nullableDuplicatePolicy: options.nullableDuplicatePolicy,
      );

      if (options.debugGraph) {
        final graphResult = validator.lastGraphResult;
        final asyncResult = validator.lastAsyncResult;
        final validEntryPoints = validator.lastValidEntryPoints;
        if (graphResult != null && asyncResult != null && validEntryPoints != null) {
          (debugEntries ??= []).add((
            componentClass: componentClass,
            entryPoints: validEntryPoints,
            graphResult: graphResult,
            asyncResult: asyncResult,
          ));
        }
      }
    }

    // Check: can we proceed to codegen?
    if (reporter.hasErrors) {
      reporter.flushToLog(log);
      return null;
    }

    // Flush diagnostics before the tree so warnings don't interleave with it.
    reporter.flushToLog(log);

    // Tree only runs on the success path so users fix diagnostics first.
    // Isolated from the build: a bug in the opt-in debug feature must not
    // abort code generation for users who only wanted a visualization aid.
    if (debugEntries != null) {
      for (var i = 0; i < debugEntries.length; i++) {
        final entry = debugEntries[i];
        if (i > 0) _debugPrint('');
        try {
          _debugPrint(
            GraphPrinter(
              componentClass: entry.componentClass,
              entryPoints: entry.entryPoints,
              graphResult: entry.graphResult,
              asyncResult: entry.asyncResult,
            ).render().trimRight(),
          );
        } catch (error, stack) {
          log.warning(
            "inject_generator: debug_graph print failed for component "
            "'${entry.componentClass.name}': $error\n$stack",
          );
        }
      }
    }

    // Phase 3: Code Generation
    final codeGenerator = CodeGenerator();
    return codeGenerator.generate(library: libraryElement, reader: reader);
  }

  @override
  String toString() => 'inject.dart\nhttps://pub.dev/packages/inject_annotation';
}
