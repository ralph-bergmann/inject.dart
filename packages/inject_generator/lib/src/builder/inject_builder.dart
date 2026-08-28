import 'dart:async';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

import '../analysis/annotation_reader.dart';
import '../analysis/assisted_reader.dart';
import '../analysis/component_reader.dart';
import '../analysis/entry_point_collector.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/subcomponent_reader.dart' show SubcomponentFactoryData;
import '../analysis/type_checkers.dart';
import '../codegen/code_generator.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/async_propagation_result.dart';
import '../validation/binding_graph_result.dart';
import '../validation/binding_key.dart';
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
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final DiagnosticReporter reporter = createReporter();
    final reader = AnnotationReader(reporter: reporter);
    final LibraryElement libraryElement = library.element;

    // Phase 1 & 2: Analysis + Validation per component
    final validator = GraphValidator(reporter: reporter);

    final List<ClassElement> componentClasses = libraryElement.classes.where(reader.isComponent).toList();

    // Tracks every subcomponent type installed by any module of this library
    // (through any component) — input for the orphan warning below.
    final installedSubcomponentElements = <Element>{};

    // Collect per-component debug data only when the debug pass is enabled.
    List<
      ({
        ClassElement componentClass,
        List<EntryPoint> entryPoints,
        BindingGraphResult graphResult,
        AsyncPropagationResult asyncResult,
      })
    >?
    debugEntries;

    for (final componentClass in componentClasses) {
      if (reader.isAssistedInject(componentClass)) {
        _reportInjectableConstructorOnComponent(reporter, componentClass, '@assistedInject');
        continue;
      }
      if (reader.hasInjectConstructor(componentClass)) {
        _reportInjectableConstructorOnComponent(reporter, componentClass, '@inject');
        continue;
      }

      final ComponentData? componentData = reader.readComponent(componentClass);
      if (componentData == null) {
        continue;
      }

      // Read modules. Only the directly-listed module types are resolved
      // here — `expandModules` follows each one's own `@Module(includes:
      // ...)` list transitively (cycle detection + dedup-by-type) so the
      // rest of the pipeline sees one flat, ordered module list exactly as
      // if every included module had been listed directly.
      final directModuleClasses = <ClassElement>[];
      for (final DartType moduleType in componentData.modules) {
        if (moduleType case InterfaceType()) {
          final InterfaceElement moduleElement = moduleType.element;
          if (moduleElement case final ClassElement classElement) {
            directModuleClasses.add(classElement);
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
      final modules = reader.expandModules(directModuleClasses);

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

      // Discover installed subcomponents and analyse their child graphs.
      final Set<BindingKey> parentProvidedKeys = collectAllProvidedKeys(
        modules: modules,
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final List<SubcomponentFactoryDescriptor> subcomponentDescriptors = discoverSubcomponentFactories(
        reader: reader,
        reporter: reporter,
        modules: modules,
        parentProvidedKeys: parentProvidedKeys,
      );
      for (final m in modules) {
        for (final subcomponentType in m.moduleData.installedSubcomponents) {
          final Element? element = subcomponentType.element;
          if (element != null) {
            installedSubcomponentElements.add(element);
          }
        }
      }

      validator.validate(
        sourceLibrary: libraryElement,
        componentClass: componentClass,
        componentData: componentData,
        modules: modules,
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
        subcomponentDescriptors: subcomponentDescriptors,
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

    // Orphan warning: a @subcomponent declared in this library that no
    // @module anywhere in the build installs is almost certainly a forgotten
    // `@Module(subcomponents: [...])` entry.
    await _warnOrphanedSubcomponents(reporter, reader, libraryElement, installedSubcomponentElements, buildStep);

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

/// Warns for every `@subcomponent` class in [libraryElement] that is not
/// installed by any `@Module(subcomponents: [...])` reachable from the
/// build (the same library, or another file — see the cross-file scan
/// below for why that matters).
///
/// Additionally warns for every explicit `@subcomponentFactory` class in
/// [libraryElement] whose target subcomponent is never installed — such a
/// factory is silently skipped by subcomponent discovery (which only visits
/// installed subcomponents), so without this warning it would have no
/// effect with no feedback at all. Both findings share the same
/// cross-package visibility boundary (a module in a different pub package
/// could install the subcomponent), which is why they are warnings, not
/// errors. When the never-installed target is declared in this same library
/// (so the orphan warning above already fires for it), the factory finding
/// is folded into that one combined warning instead of doubling it.
Future<void> _warnOrphanedSubcomponents(
  DiagnosticReporter reporter,
  AnnotationReader reader,
  LibraryElement libraryElement,
  Set<Element> installedSubcomponentElements,
  BuildStep buildStep,
) async {
  // Also accept installation by modules of this library that are not used
  // by any component in this library (the component may live elsewhere).
  final Set<ClassElement> orphanCandidates = {
    for (final classElement in libraryElement.classes)
      if (reader.isSubcomponent(classElement) && !installedSubcomponentElements.contains(classElement)) classElement,
  };

  // Explicit `@subcomponentFactory` classes of this library whose target is
  // not already known to be installed, keyed by that target. `validate:
  // false` — a malformed factory is diagnosed once, by the authoritative
  // factory-builder pass, and has no resolvable target to check here.
  final factoriesByTarget = <ClassElement, List<ClassElement>>{};
  for (final ClassElement classElement in libraryElement.classes) {
    if (!reader.isSubcomponentFactory(classElement)) {
      continue;
    }
    final SubcomponentFactoryData? factoryData = reader.readSubcomponentFactory(classElement, validate: false);
    if (factoryData == null) {
      continue;
    }
    if (!installedSubcomponentElements.contains(factoryData.subcomponentClass)) {
      factoriesByTarget.putIfAbsent(factoryData.subcomponentClass, () => []).add(classElement);
    }
  }

  if (orphanCandidates.isEmpty && factoriesByTarget.isEmpty) {
    return;
  }

  final Set<ClassElement> stillOrphaned = {...orphanCandidates, ...factoriesByTarget.keys};
  for (final moduleClass in libraryElement.classes.where(reader.isModule)) {
    stillOrphaned.removeWhere(
      (subcomponent) => reader
          .readModule(moduleClass)
          .installedSubcomponents
          .any((subcomponentType) => subcomponentType.element == subcomponent),
    );
  }

  // A `@subcomponent` may be installed by a module declared in a different
  // *file* than the one declaring the `@subcomponent` itself — inject.dart's
  // module system is explicitly designed to compose across files (README,
  // "Encapsulating subgraphs"), and subcomponents are no exception. A
  // `Generator`'s own `Resolver` only reaches libraries importable *from*
  // the library it is currently processing, which is the wrong direction
  // here (the installing module's file imports the subcomponent's file, not
  // the other way around) — so answering "is this installed anywhere" needs
  // a package-wide scan via `BuildStep.findAssets` instead.
  //
  // This covers same-package, cross-file composition, which is the common
  // case this finding is about. It does not (and structurally cannot,
  // without a whole-build aggregation builder) see a module installed in a
  // *different pub package* — `findAssets` only sees the current package.
  //
  // Uses a diagnostic-free peek at each module's raw `@Module(subcomponents:
  // ...)` annotation (not `reader.readModule`, which reports errors) so a
  // malformed module in another file isn't re-diagnosed here — that file's
  // own build pass already reports its own errors.
  if (stillOrphaned.isNotEmpty) {
    await for (final AssetId assetId in buildStep.findAssets(Glob('**.dart'))) {
      if (stillOrphaned.isEmpty) {
        break;
      }
      if (assetId.path.endsWith('.g.dart') || assetId.path.endsWith('.inject.dart')) {
        continue; // Generated output never declares a hand-written @module.
      }
      if (!await buildStep.resolver.isLibrary(assetId)) {
        continue; // Part files, non-Dart assets, etc.
      }
      final LibraryElement otherLibrary = await buildStep.resolver.libraryFor(assetId);
      for (final ClassElement moduleClass in otherLibrary.classes) {
        if (stillOrphaned.isEmpty) {
          break;
        }
        if (!reader.isModule(moduleClass)) {
          continue;
        }
        stillOrphaned.removeWhere((subcomponent) => _modulePeekInstalls(moduleClass, subcomponent));
      }
    }
  }

  for (final classElement in stillOrphaned) {
    final List<ClassElement> inertFactories = factoriesByTarget[classElement] ?? const [];
    if (orphanCandidates.contains(classElement)) {
      // Declared in this library — the orphan warning anchors at the
      // subcomponent. Any inert factory of this same library is folded into
      // the message instead of doubling the finding.
      final String factoryClause = switch (inertFactories.length) {
        0 => '',
        1 =>
          " The @subcomponentFactory '${inertFactories.single.name}' targeting it has no effect "
              'until the subcomponent is installed.',
        _ =>
          ' The @subcomponentFactory classes '
              '${inertFactories.map((f) => "'${f.name}'").join(', ')} targeting it have no effect '
              'until the subcomponent is installed.',
      };
      reporter.warningForElement(
        classElement,
        message: "Subcomponent '${classElement.name}' is declared but never installed.$factoryClause",
        suggestion:
            'Add it to a module via @Module(subcomponents: [${classElement.name}]) '
            'so a parent component can create it, or remove the @subcomponent annotation.',
      );
    } else {
      // The target is declared in a different library — this library only
      // holds the factory, so the warning anchors there.
      for (final ClassElement factoryClass in inertFactories) {
        reporter.warningForElement(
          factoryClass,
          message:
              "Factory '${factoryClass.name}' is annotated with @subcomponentFactory but its "
              "target subcomponent '${classElement.name}' is never installed — the factory has "
              'no effect.',
          suggestion:
              'Add the subcomponent to a module via @Module(subcomponents: [${classElement.name}]) '
              'so a parent component can create it through this factory.',
        );
      }
    }
  }
}

/// Returns `true` when [moduleClass]'s `@Module(subcomponents: ...)`
/// annotation lists [subcomponentElement], without reporting any
/// diagnostics — used only for the cross-library orphan scan above, which
/// must not re-report issues in a module owned by a different library's
/// build pass.
bool _modulePeekInstalls(ClassElement moduleClass, Element subcomponentElement) {
  final DartObject? annotation = moduleChecker.firstAnnotationOf(moduleClass);
  if (annotation == null) {
    return false;
  }
  final ConstantReader subcomponentsReader = ConstantReader(annotation).read('subcomponents');
  if (!subcomponentsReader.isList) {
    return false;
  }
  for (final DartObject obj in subcomponentsReader.listValue) {
    if (obj.toTypeValue()?.element == subcomponentElement) {
      return true;
    }
  }
  return false;
}

/// Reports that [componentClass] declares an injectable constructor.
///
/// A `@Component` class is generated by inject.dart and must declare no
/// `@inject`/`@assistedInject` constructors of its own — those belong on the
/// injectable classes the component provides.
void _reportInjectableConstructorOnComponent(
  DiagnosticReporter reporter,
  ClassElement componentClass,
  String annotationName,
) {
  reporter.errorForElement(
    componentClass,
    message:
        "@Component class '${componentClass.name}' declares an $annotationName constructor. "
        'A component is generated by inject.dart and declares no injectable constructors; '
        '$annotationName belongs on the injectable classes a component provides.',
    suggestion:
        'Move the $annotationName constructor to a separate injectable class that the '
        'component exposes, or remove @Component if this class is meant to be injectable.',
  );
}
