import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../logging/diagnostic_reporter.dart';
import 'entry_point_collector.dart';
import 'type_checkers.dart';

/// Result of reading a `@component`-annotated class.
///
/// Contains the module types referenced by the component and the
/// entry-point accessors/methods annotated with `@inject`, each
/// carrying its full qualifier-aware binding identity.
typedef ComponentData = ({List<DartType> modules, List<EntryPoint> entryPoints});

/// Reads `@component` / `@Component([...])` annotations and extracts
/// module references and component entry points.
class ComponentReader {
  /// Creates a [ComponentReader] reporting through [reporter].
  ComponentReader({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  late final _entryPointCollector = EntryPointCollector(reporter: reporter);

  /// Reads the `@component` annotation from [classElement] and returns
  /// the extracted [ComponentData].
  ///
  /// Returns `null` if the annotation could not be read.
  ComponentData? readComponent(ClassElement classElement) {
    final DartObject? annotation = componentChecker.firstAnnotationOf(classElement);
    if (annotation == null) {
      reporter.errorForElement(
        classElement,
        message: "Class '${classElement.name}' is missing @component annotation metadata.",
        suggestion: 'Ensure the class is annotated with @component or @Component([...]).',
      );
      return null;
    }

    final reader = ConstantReader(annotation);

    // Extract module types from Component.modules field. Duplicates are
    // reported as errors to prevent accidental double-listing that would
    // emit duplicate required parameters in the generated factory.
    final ConstantReader modulesReader = reader.read('modules');
    final modules = <DartType>[];
    final seenModuleElements = <Element>{};
    for (final DartObject obj in modulesReader.listValue) {
      final DartType? dartType = obj.toTypeValue();
      if (dartType == null) {
        continue;
      }
      final Element? typeElement = dartType.element;
      if (typeElement != null && !seenModuleElements.add(typeElement)) {
        reporter.errorForElement(
          classElement,
          message:
              "Module '${dartType.getDisplayString()}' is listed more than once in @Component "
              "on '${classElement.name}'.",
          suggestion: 'Remove the duplicate module entry.',
        );
        continue;
      }
      // A `@subcomponent` type listed like a module is the classic Dagger
      // migration mistake — without this check it would silently degrade to
      // an empty module. Mirrors the inverse check in
      // `ModuleReader._readInstalledSubcomponents` (a non-@subcomponent type
      // in `@Module(subcomponents: [...])`).
      if (typeElement != null && subcomponentChecker.hasAnnotationOf(typeElement)) {
        reporter.errorForElement(
          classElement,
          message:
              "Type '${dartType.getDisplayString()}' in @Component on '${classElement.name}' is "
              'annotated with @subcomponent — a subcomponent cannot be listed as a module.',
          suggestion:
              'Install it via @Module(subcomponents: [${dartType.getDisplayString()}]) on one of '
              "the component's modules instead.",
        );
        continue;
      }
      modules.add(dartType);
    }

    final List<EntryPoint> entryPoints = _entryPointCollector.collectEntryPoints(classElement);

    return (modules: modules, entryPoints: entryPoints);
  }
}
