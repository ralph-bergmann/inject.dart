import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';

import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import '../analysis/annotation_reader.dart';
import '../codegen/factory_code_generator.dart';
import '../logging/diagnostic_reporter.dart';
import 'factory_builder_options.dart';

/// Builder entry point for `.factory.dart` generation.
///
/// Runs as a `PartBuilder` before the main inject builder to ensure
/// assisted factory artifacts are available before the injection output
/// depends on them.
///
/// Validates the `part` contract, then delegates annotation reading,
/// visibility validation, and code generation to [FactoryCodeGenerator].
class FactoryBuilder extends Generator {
  /// Creates a [FactoryBuilder] with the given [options].
  const FactoryBuilder({this.options = FactoryBuilderOptions.defaults});

  /// Parsed `factory_builder` options from `build.yaml`.
  final FactoryBuilderOptions options;

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    final LibraryElement libraryElement = library.element;
    final reporter = DiagnosticReporter();
    final annotationReader = AnnotationReader(reporter: reporter);

    // Check if any class in the library has @assistedInject.
    final List<ClassElement> assistedInjectClasses = libraryElement.classes
        .where(annotationReader.isAssistedInject)
        .toList();

    if (assistedInjectClasses.isEmpty) {
      return null;
    }

    // Determine which @assistedInject classes have matching explicit
    // @assistedFactory declarations. Only orphan classes (synthesized case)
    // require a .factory.dart part file for the generated abstract factory type.
    // Explicit factories are handled via inline factories in .inject.dart.
    final List<ClassElement> assistedFactoryClasses = libraryElement.classes
        .where(annotationReader.isAssistedFactory)
        .toList();

    final matchedInjectElements = <ClassElement>{};
    for (final factoryClass in assistedFactoryClasses) {
      for (final MethodElement method in factoryClass.methods) {
        if (method.isAbstract) {
          if (method.returnType case InterfaceType(:final element)) {
            final Iterable<ClassElement> matched = assistedInjectClasses.where((c) => c == element);
            matchedInjectElements.addAll(matched);
          }
        }
      }
    }

    final bool hasOrphans = assistedInjectClasses.any((c) => !matchedInjectElements.contains(c));

    // Validate part directive: the source library must declare
    // part '<file>.factory.dart'; when synthesized factories are needed.
    final LibraryFragment fragment = libraryElement.firstFragment;
    final Uri sourceUri = fragment.source.uri;
    final String fileName = sourceUri.pathSegments.last;
    final String expectedPartName = p.setExtension(fileName, '.factory.dart');
    final bool hasFactoryPart = fragment.partIncludes.any((part) {
      final DirectiveUri partUri = part.uri;
      if (partUri case final DirectiveUriWithRelativeUriString uriWithString) {
        return uriWithString.relativeUriString == expectedPartName;
      }
      return false;
    });

    if (!hasFactoryPart) {
      if (hasOrphans) {
        reporter
          ..error(
            filePath: sourceUri.toString(),
            line: 1,
            column: 1,
            message: 'Library declares @assistedInject but is missing the required part directive.',
            suggestion: "Add \"part '$expectedPartName';\" to the top of this file.",
          )
          ..flushToLog(log);
      }
      return null;
    }

    // Code generation (reads annotations, validates visibility, generates output).
    final String? output = FactoryCodeGenerator().generate(library: libraryElement, reader: annotationReader);

    // Flush any diagnostics collected during analysis and codegen.
    reporter.flushToLog(log);

    return output;
  }

  @override
  String toString() => 'inject.dart\nhttps://pub.dev/packages/inject_annotation';
}
