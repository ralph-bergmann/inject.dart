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
    // Component classes are excluded: a @Component class must declare no
    // injectable constructors — InjectBuilder reports that diagnostic and
    // this exclusion prevents a dead .factory.dart for the malformed input.
    final List<ClassElement> assistedInjectClasses = libraryElement.classes
        .where((c) => annotationReader.isAssistedInject(c) && !annotationReader.isComponent(c))
        .toList();

    // Libraries declaring @subcomponent classes also need the part file:
    // it carries the public abstract <Name>Factory class.
    final List<ClassElement> subcomponentClasses = libraryElement.classes
        .where(annotationReader.isSubcomponent)
        .toList();

    if (assistedInjectClasses.isEmpty && subcomponentClasses.isEmpty) {
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

    // Same idea for @subcomponent classes: one with a matching explicit
    // @subcomponentFactory needs no synthesized <Name>Factory, so it does
    // not, by itself, require a .factory.dart part file. A lightweight
    // structural scan (no annotation-reading, no diagnostics) — mirrors the
    // assistedFactory matching above; the real, diagnostic-producing read
    // happens once in `FactoryCodeGenerator.generate`.
    final List<ClassElement> subcomponentFactoryClasses = libraryElement.classes
        .where(annotationReader.isSubcomponentFactory)
        .toList();
    final matchedSubcomponentElements = <ClassElement>{};
    for (final factoryClass in subcomponentFactoryClasses) {
      for (final MethodElement method in factoryClass.methods) {
        if (method.isAbstract) {
          if (method.returnType case InterfaceType(:final element)) {
            final Iterable<ClassElement> matched = subcomponentClasses.where((c) => c == element);
            matchedSubcomponentElements.addAll(matched);
          }
        }
      }
    }

    final bool hasOrphans =
        assistedInjectClasses.any((c) => !matchedInjectElements.contains(c)) ||
        subcomponentClasses.any((c) => !matchedSubcomponentElements.contains(c));

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
            message:
                'Library declares @assistedInject or @subcomponent but is missing the '
                'required part directive.',
            suggestion: "Add \"part '$expectedPartName';\" to the top of this file.",
          )
          ..flushToLog(log);
        return null;
      }
      if (subcomponentFactoryClasses.isEmpty) {
        return null;
      }
      // Nothing needs to be emitted (every subcomponent has a matching
      // explicit factory), but explicit @subcomponentFactory classes still
      // need their own cross-class validation (e.g. two factories targeting
      // the same subcomponent) — fall through to FactoryCodeGenerator, whose
      // `generate` call below returns null harmlessly once that runs.
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
