import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../codegen/naming.dart';
import '../extensions/constructor_element_extensions.dart';
import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/binding_key.dart';
import 'module_reader.dart' show ParameterDependency;
import 'type_checkers.dart';

/// Result of reading an `@inject`-annotated class.
typedef InjectableData = ({
  BindingKey key,
  ConstructorElement constructor,
  String? constructorName,
  List<ParameterDependency> dependencies,
  bool isSingleton,
});

/// Reads `@inject`-annotated classes and extracts constructor dependencies
/// and class-level binding metadata.
class InjectReader {
  /// Creates an [InjectReader] reporting through [reporter].
  InjectReader({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  /// Reads the `@inject` annotation from [classElement] and returns
  /// the extracted [InjectableData] entries.
  ///
  /// Returns one entry per `@inject`-annotated constructor. When multiple
  /// constructors carry `@inject`, each must have a unique `@Qualifier`.
  ///
  /// Returns an empty list if no suitable constructor is found.
  List<InjectableData> readInjectables(ClassElement classElement) {
    final List<ConstructorElement> constructors = _findInjectConstructors(classElement);
    if (constructors.isEmpty) {
      return [];
    }

    // Warn if @asynchronous is placed on an @inject class — it has no effect.
    if (asynchronousChecker.hasAnnotationOf(classElement)) {
      reporter.warningForElement(
        classElement,
        message:
            "'@asynchronous' on class '${classElement.name}' has no "
            "effect and is ignored. '@asynchronous' is only valid on "
            "'@provides' methods in @module classes.",
        suggestion:
            "Remove '@asynchronous' from the class. If you need "
            'asynchronous provider resolution, use a @provides method in '
            'a @module class instead.',
      );
    }
    for (final constructor in constructors) {
      if (asynchronousChecker.hasAnnotationOf(constructor)) {
        final String? constructorName = constructor.constructorName;
        final String? classConstructorName = constructorName != null
            ? '${classElement.name}.$constructorName'
            : classElement.name;
        reporter.warningForElement(
          constructor,
          message:
              "'@asynchronous' on constructor '$classConstructorName' has no "
              "effect and is ignored. '@asynchronous' is only valid on "
              "'@provides' methods in @module classes.",
          suggestion:
              "Remove '@asynchronous' from the constructor. If you need "
              'asynchronous provider resolution, use a @provides method in '
              'a @module class instead.',
        );
      }
    }

    final bool isSingleton = singletonChecker.hasAnnotationOf(classElement);
    final results = <InjectableData>[];

    for (final constructor in constructors) {
      final dependencies = <ParameterDependency>[];
      for (final FormalParameterElement param in constructor.formalParameters) {
        // A `Provider<T>` constructor parameter is injected like any other
        // dependency: unwrap to the inner `T` binding and remember to pass the
        // provider itself (not its resolved value) during code generation.
        final ({DartType type, bool isProvider}) unwrapped = param.type.unwrapProviderParam();
        dependencies.add((
          parameter: param,
          type: unwrapped.type,
          qualifier: param.readQualifier(),
          isProvider: unwrapped.isProvider,
        ));
      }

      final String? qualifier = constructor.readQualifier();

      final BindingKey? key = BindingKey.fromDartType(classElement.thisType, qualifier: qualifier);
      if (key == null) {
        reporter.errorForElement(
          classElement,
          message: "Unsupported type for @inject class '${classElement.name}'.",
          suggestion: 'Use an interface type or wrap the dependency in a typedef or class.',
        );
        continue;
      }

      results.add((
        key: key,
        constructor: constructor,
        constructorName: constructor.constructorName,
        dependencies: dependencies,
        isSingleton: isSingleton,
      ));
    }

    return results;
  }

  /// Reads the `@inject` annotation from [classElement] and returns
  /// the extracted [InjectableData].
  ///
  /// Returns `null` if no suitable constructor is found.
  InjectableData? readInjectable(ClassElement classElement) {
    final List<InjectableData> results = readInjectables(classElement);
    return results.isEmpty ? null : results.first;
  }

  List<ConstructorElement> _findInjectConstructors(ClassElement classElement) {
    final List<ConstructorElement> annotatedConstructors = classElement.constructors
        .where((c) => injectChecker.hasAnnotationOf(c))
        .toList();

    if (annotatedConstructors.length > 1) {
      // Multiple @inject constructors — validate each has unique @Qualifier.
      final qualifiers = <String?>{};
      for (final constructor in annotatedConstructors) {
        final String? qualifier = constructor.readQualifier();
        if (qualifier == null) {
          reporter.errorForElement(
            classElement,
            message:
                "Multiple @inject constructors on '${classElement.name}' "
                'require unique @Qualifier annotations.',
            suggestion:
                'Add distinct @Qualifier annotations to each @inject '
                'constructor, or keep @inject on only one constructor.',
          );
          return [];
        }
        if (!isValidQualifierIdentifier(qualifier)) {
          reporter.errorForElement(
            classElement,
            message:
                "Invalid @Qualifier symbol '$qualifier' on constructor of "
                "'${classElement.name}' — symbols used as multi-constructor "
                'discriminators must form a valid Dart identifier suffix.',
            suggestion:
                'Qualifier symbols must be non-empty and contain only Dart '
                'identifier characters [a-zA-Z0-9_]. Avoid hyphens, dots, '
                'spaces, and other punctuation.',
          );
          return [];
        }
        if (!qualifiers.add(qualifier)) {
          reporter.errorForElement(
            classElement,
            message: "Duplicate @Qualifier on constructors of '${classElement.name}'.",
            suggestion:
                'Each @inject constructor must have a unique @Qualifier '
                'annotation.',
          );
          return [];
        }
      }
      return annotatedConstructors;
    }

    if (annotatedConstructors.length == 1) {
      return annotatedConstructors;
    }

    // No annotated constructor — require @inject on the class level.
    // Without @inject anywhere, this class is NOT injectable.
    // Unannotated classes are never injectable — they produce a
    // missing-binding error in BindingResolver.
    if (!injectChecker.hasAnnotationOf(classElement)) {
      return [];
    }

    // @inject is on the class. If there's exactly one constructor, use it
    // regardless of its name.
    final List<ConstructorElement> constructors = classElement.constructors;
    if (constructors.length == 1) {
      return [constructors.first];
    }

    // Multiple constructors — try unnamed as default, otherwise error.
    final ConstructorElement? unnamed = classElement.unnamedConstructor;
    if (unnamed != null) {
      return [unnamed];
    }

    reporter.errorForElement(
      classElement,
      message:
          "Class '${classElement.name}' has multiple constructors but none "
          'is annotated with @inject.',
      suggestion:
          'Annotate the desired constructor with @inject, '
          'or use @provides in a module.',
    );
    return [];
  }
}
