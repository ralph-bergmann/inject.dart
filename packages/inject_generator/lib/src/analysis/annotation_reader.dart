import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import '../logging/diagnostic_reporter.dart';
import 'assisted_reader.dart';
import 'component_reader.dart';
import 'inject_reader.dart';
import 'module_reader.dart';
import 'type_checkers.dart';

/// Facade for annotation detection — delegates to shared TypeCheckers.
///
/// The single entry point for the analysis phase. Exposes `readComponent()`,
/// `readModule()`, etc. that delegate to specialized sub-readers.
class AnnotationReader {
  /// Creates an [AnnotationReader] reporting through [reporter].
  AnnotationReader({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  late final _componentReader = ComponentReader(reporter: reporter);
  late final _moduleReader = ModuleReader(reporter: reporter);
  late final _injectReader = InjectReader(reporter: reporter);
  late final _assistedReader = AssistedReader(reporter: reporter);

  /// Returns `true` if [element] has a `@component` / `@Component(...)` annotation.
  bool isComponent(ClassElement element) => _hasAnnotation(componentChecker, element);

  /// Returns `true` if [element] has a `@module` annotation.
  bool isModule(ClassElement element) => _hasAnnotation(moduleChecker, element);

  /// Returns `true` if [element] has an `@inject` annotation on the class
  /// itself or on any of its constructors.
  bool isInjectable(ClassElement element) {
    if (_hasAnnotation(injectChecker, element)) {
      return true;
    }

    return element.constructors.any((constructor) => _hasAnnotation(injectChecker, constructor));
  }

  /// Returns `true` if [element] has a `@singleton` annotation.
  bool isSingleton(Element element) => _hasAnnotation(singletonChecker, element);

  /// Returns `true` if [element] has an `@asynchronous` annotation.
  bool isAsynchronous(Element element) => _hasAnnotation(asynchronousChecker, element);

  /// Returns `true` if [element] has a `@Qualifier(#name)` annotation.
  bool hasQualifier(Element element) => _hasAnnotation(qualifierChecker, element);

  /// Returns `true` if [element] has a `@provides` annotation.
  bool hasProvides(MethodElement element) => _hasAnnotation(providesChecker, element);

  /// Returns `true` if [element] has a `@provisionListener` annotation.
  bool isProvisionListener(MethodElement element) => _hasAnnotation(provisionListenerChecker, element);

  bool _hasAnnotation(TypeChecker checker, Element element) {
    try {
      return checker.hasAnnotationOf(element);
    } on UnresolvedAnnotationException catch (e) {
      reporter.warningForElement(
        element,
        message:
            "Could not resolve annotation on element '${element.name}': "
            '${e.annotationSource?.text ?? 'unknown annotation'}.',
        suggestion:
            'Ensure all imports are valid and the annotation package '
            'is available on the pub path.',
      );
      // Re-check without throwing so valid annotations on the same element
      // are not masked by an unrelated unresolvable annotation.
      return checker.hasAnnotationOf(element, throwOnUnresolved: false);
    }
  }

  /// Reads the `@component` annotation from [classElement] and returns
  /// module references and entry points. Delegates to [ComponentReader].
  ComponentData? readComponent(ClassElement classElement) => _componentReader.readComponent(classElement);

  /// Reads the `@module` class and returns provider method descriptors.
  /// Delegates to [ModuleReader].
  ModuleData readModule(ClassElement classElement) => _moduleReader.readModule(classElement);

  /// Reads the `@inject`-annotated class and returns constructor dependencies
  /// and binding metadata. Delegates to [InjectReader].
  InjectableData? readInjectable(ClassElement classElement) => _injectReader.readInjectable(classElement);

  /// Reads the `@inject`-annotated class and returns all injectable entries.
  /// For classes with multiple `@inject` constructors (each with a unique
  /// `@Qualifier`), this returns one entry per constructor.
  /// Delegates to [InjectReader].
  List<InjectableData> readInjectables(ClassElement classElement) => _injectReader.readInjectables(classElement);

  /// Returns `true` if [element] has an `@assistedInject` annotation on
  /// any of its constructors.
  bool isAssistedInject(ClassElement element) =>
      element.constructors.any((constructor) => _hasAnnotation(assistedInjectChecker, constructor));

  /// Returns `true` if [element] has an `@assistedFactory` annotation.
  bool isAssistedFactory(ClassElement element) => _hasAnnotation(assistedFactoryChecker, element);

  /// Reads the `@assistedInject`-annotated class and returns partitioned
  /// constructor dependencies. Delegates to [AssistedReader].
  AssistedInjectData? readAssistedInject(ClassElement classElement) => _assistedReader.readAssistedInject(classElement);

  /// Reads the `@assistedInject`-annotated class and returns all entries.
  /// For classes with multiple `@assistedInject` constructors (each with a
  /// unique `@Qualifier`), this returns one entry per constructor.
  /// Delegates to [AssistedReader].
  List<AssistedInjectData> readAssistedInjects(ClassElement classElement) =>
      _assistedReader.readAssistedInjects(classElement);

  /// Reads the `@assistedFactory`-annotated class and returns factory
  /// method metadata. Delegates to [AssistedReader].
  AssistedFactoryData? readAssistedFactory(ClassElement classElement) =>
      _assistedReader.readAssistedFactory(classElement);
}
