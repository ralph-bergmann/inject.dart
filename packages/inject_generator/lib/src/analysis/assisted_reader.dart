import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../codegen/naming.dart';
import '../extensions/constructor_element_extensions.dart';
import '../extensions/element_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/binding_key.dart';
import 'module_reader.dart' show ParameterDependency;
import 'type_checkers.dart';

/// Result of reading an `@assistedInject`-annotated constructor.
typedef AssistedInjectData = ({
  BindingKey key,
  ConstructorElement constructor,
  String? constructorName,
  List<ParameterDependency> injectedDependencies,
  List<ParameterDependency> assistedParameters,
  bool isSingleton,
});

/// Result of reading an `@assistedFactory`-annotated class.
typedef AssistedFactoryData = ({
  ClassElement factoryElement,
  MethodElement createMethod,
  DartType targetType,
  String? targetQualifier,
  List<ParameterDependency> assistedParameters,
});

/// Reads `@assistedInject`-annotated classes and extracts constructor
/// dependencies partitioned into injected and assisted parameters.
class AssistedReader {
  /// Creates an [AssistedReader] reporting through [reporter].
  AssistedReader({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  /// Reads `@assistedInject` annotations from [classElement] and returns
  /// the extracted [AssistedInjectData] entries.
  ///
  /// Returns one entry per `@assistedInject`-annotated constructor. When
  /// multiple constructors carry `@assistedInject`, each must have a unique
  /// `@Qualifier`.
  ///
  /// Returns an empty list if no constructor is annotated, if qualifier
  /// validation fails (diagnostic emitted), or if an annotated constructor
  /// has no `@assisted` parameters (diagnostic emitted).
  List<AssistedInjectData> readAssistedInjects(ClassElement classElement) {
    final List<ConstructorElement> annotatedConstructors = classElement.constructors
        .where((c) => assistedInjectChecker.hasAnnotationOf(c))
        .toList();

    if (annotatedConstructors.isEmpty) {
      return [];
    }

    if (annotatedConstructors.length > 1) {
      // Multiple @assistedInject constructors — validate each has unique @Qualifier
      // AND that the resulting synthesized factory class names are also unique
      // (e.g. #brandName and #BrandName collapse to the same `BrandNameFactory`).
      final qualifiers = <String?>{};
      final synthesizedNames = <String>{};
      for (final constructor in annotatedConstructors) {
        final String? qualifier = constructor.readQualifier();
        if (qualifier == null) {
          reporter.errorForElement(
            classElement,
            message:
                "Multiple @assistedInject constructors on '${classElement.name}' "
                'require unique @Qualifier annotations.',
            suggestion:
                'Add distinct @Qualifier annotations to each @assistedInject '
                'constructor, or keep @assistedInject on only one constructor.',
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
                'Each @assistedInject constructor must have a unique '
                '@Qualifier annotation.',
          );
          return [];
        }
        final String synthesizedName = synthesizedFactoryClassName(classElement.name!, qualifier);
        if (!synthesizedNames.add(synthesizedName)) {
          reporter.errorForElement(
            classElement,
            message:
                "Synthesized factory class name '$synthesizedName' would collide "
                "between two @assistedInject constructors of '${classElement.name}'.",
            suggestion:
                'Two distinct @Qualifier symbols capitalize to the same suffix '
                '(e.g. #brandName and #BrandName both → BrandNameFactory). '
                'Pick qualifier symbols whose first-character casing differs '
                'beyond the leading character.',
          );
          return [];
        }
      }
    }

    final bool isSingleton = singletonChecker.hasAnnotationOf(classElement);
    final results = <AssistedInjectData>[];

    for (final constructor in annotatedConstructors) {
      final injectedDependencies = <ParameterDependency>[];
      final assistedParameters = <ParameterDependency>[];

      for (final FormalParameterElement param in constructor.formalParameters) {
        final String? qualifier = param.readQualifier();
        final ({FormalParameterElement parameter, String? qualifier, DartType type, bool isProvider}) dependency = (
          parameter: param,
          type: param.type,
          qualifier: qualifier,
          isProvider: false,
        );

        if (assistedChecker.hasAnnotationOf(param)) {
          assistedParameters.add(dependency);
        } else {
          injectedDependencies.add(dependency);
        }
      }

      if (assistedParameters.isEmpty) {
        reporter.errorForElement(
          constructor,
          message:
              "Constructor of '${classElement.name}' is annotated with "
              '@assistedInject but has no @assisted parameters.',
          suggestion:
              'Mark at least one parameter with @assisted to indicate '
              'which values are supplied by the caller.',
        );
        continue;
      }

      final String? qualifier = constructor.readQualifier();

      final BindingKey? key = BindingKey.fromDartType(classElement.thisType, qualifier: qualifier);
      if (key == null) {
        reporter.errorForElement(
          classElement,
          message:
              'Unsupported type for @assistedInject class '
              "'${classElement.name}'.",
          suggestion:
              'Use an interface type or wrap the dependency in a typedef '
              'or class.',
        );
        continue;
      }

      results.add((
        key: key,
        constructor: constructor,
        constructorName: constructor.constructorName,
        injectedDependencies: injectedDependencies,
        assistedParameters: assistedParameters,
        isSingleton: isSingleton,
      ));
    }

    return results;
  }

  /// Reads the `@assistedInject` annotation from [classElement] and returns
  /// the extracted [AssistedInjectData].
  ///
  /// Returns `null` if no suitable constructor is found.
  AssistedInjectData? readAssistedInject(ClassElement classElement) {
    final List<AssistedInjectData> results = readAssistedInjects(classElement);
    return results.isEmpty ? null : results.first;
  }

  /// Reads the `@assistedFactory` annotation from [classElement] and returns
  /// the extracted [AssistedFactoryData].
  ///
  /// Returns `null` if the class is not abstract, has zero or multiple
  /// abstract methods, or has parameter mismatches with the target
  /// constructor's `@assisted` parameters (diagnostics emitted).
  AssistedFactoryData? readAssistedFactory(ClassElement classElement) {
    if (!classElement.isAbstract) {
      reporter.errorForElement(
        classElement,
        message:
            "Class '${classElement.name}' is annotated with "
            '@assistedFactory but is not abstract.',
        suggestion: 'Make the class abstract.',
      );
      return null;
    }

    final List<MethodElement> abstractMethods = classElement.methods.where((m) => m.isAbstract).toList();
    if (abstractMethods.isEmpty) {
      reporter.errorForElement(
        classElement,
        message: "Factory '${classElement.name}' has no abstract method.",
        suggestion:
            'Add exactly one abstract method that returns the '
            'assisted-inject target type.',
      );
      return null;
    }
    if (abstractMethods.length > 1) {
      reporter.errorForElement(
        classElement,
        message:
            "Factory '${classElement.name}' has "
            '${abstractMethods.length} abstract methods.',
        suggestion:
            'An @assistedFactory class must have exactly one '
            'abstract method.',
      );
      return null;
    }

    final MethodElement createMethod = abstractMethods.first;
    final DartType targetType = createMethod.returnType;
    final String? targetQualifier = createMethod.readQualifier();

    // Validate that the return type is an interface type pointing to a class.
    if (targetType case final InterfaceType interfaceType) {
      final InterfaceElement targetElement = interfaceType.element;
      if (targetElement case final ClassElement targetClassElement) {
        // Find the @assistedInject-annotated constructor matching the qualifier.
        final List<ConstructorElement> annotatedConstructors = targetClassElement.constructors
            .where((c) => assistedInjectChecker.hasAnnotationOf(c))
            .toList();

        ConstructorElement? targetConstructor;
        if (targetQualifier != null) {
          // Qualifier specified — find the constructor with matching qualifier.
          targetConstructor = annotatedConstructors.where((c) => c.readQualifier() == targetQualifier).firstOrNull;
        } else if (annotatedConstructors.length == 1) {
          // No qualifier and single constructor — use it.
          targetConstructor = annotatedConstructors.first;
        } else if (annotatedConstructors.length > 1) {
          // No qualifier but multiple constructors — ambiguous.
          reporter.errorForElement(
            createMethod,
            message:
                "Factory method '${createMethod.name}' returns "
                "'${targetClassElement.name}' which has multiple "
                '@assistedInject constructors but no @Qualifier is '
                'specified on the factory method.',
            suggestion:
                'Add a @Qualifier annotation to the factory method to '
                'indicate which @assistedInject constructor to use.',
          );
          return null;
        }

        if (targetConstructor == null) {
          reporter.errorForElement(
            classElement,
            message:
                "Factory '${classElement.name}' returns "
                "'${targetClassElement.name}' which has no "
                '@assistedInject constructor'
                '${targetQualifier != null ? " with qualifier '$targetQualifier'" : ''}.',
            suggestion:
                'The factory method must return a type that has a '
                'constructor annotated with @assistedInject'
                '${targetQualifier != null ? ' and the matching @Qualifier' : ''}.',
          );
          return null;
        }

        // Collect the target constructor's @assisted parameters for validation.
        final List<FormalParameterElement> targetAssistedParams = targetConstructor.formalParameters
            .where((p) => assistedChecker.hasAnnotationOf(p))
            .toList();

        final List<FormalParameterElement> factoryParams = createMethod.formalParameters;

        // Validate parameter count matches.
        if (factoryParams.length != targetAssistedParams.length) {
          reporter.errorForElement(
            createMethod,
            message:
                "Factory method '${createMethod.name}' has "
                '${factoryParams.length} parameter(s) but the target '
                'constructor has ${targetAssistedParams.length} @assisted '
                'parameter(s).',
            suggestion:
                'The factory method parameters must match the @assisted '
                'parameters of the target constructor.',
          );
          return null;
        }

        final List<FormalParameterElement> positionalFactoryParams = factoryParams
            .where((param) => !param.isNamed)
            .toList();
        final namedFactoryParams = <String, FormalParameterElement>{
          for (final param in factoryParams.where((param) => param.isNamed)) param.name!: param,
        };

        var positionalIndex = 0;
        for (final targetParam in targetAssistedParams) {
          if (targetParam.isNamed) {
            final FormalParameterElement? matchingFactoryParam = namedFactoryParams[targetParam.name];
            if (matchingFactoryParam == null) {
              reporter.errorForElement(
                createMethod,
                message:
                    "Factory method '${createMethod.name}' is missing named parameter "
                    "'${targetParam.name}' required by the target constructor.",
                suggestion:
                    'Align the factory method parameters with the @assisted '
                    'parameters of the target constructor, matching named '
                    'parameter names exactly.',
              );
              return null;
            }

            final DartType factoryParamType = matchingFactoryParam.type;
            final DartType targetParamType = targetParam.type;
            if (factoryParamType != targetParamType) {
              reporter.errorForElement(
                matchingFactoryParam,
                message:
                    "Factory parameter '${matchingFactoryParam.name}' has type "
                    "'${factoryParamType.getDisplayString()}' but the "
                    'corresponding @assisted parameter '
                    "'${targetParam.name}' has type "
                    "'${targetParamType.getDisplayString()}'.",
                suggestion:
                    'Align the factory method parameter types with the '
                    '@assisted parameter types of the target constructor.',
              );
              return null;
            }
            continue;
          }

          final FormalParameterElement matchingFactoryParam = positionalFactoryParams[positionalIndex];
          positionalIndex++;

          final DartType factoryParamType = matchingFactoryParam.type;
          final DartType targetParamType = targetParam.type;
          if (factoryParamType != targetParamType) {
            reporter.errorForElement(
              matchingFactoryParam,
              message:
                  "Factory parameter '${matchingFactoryParam.name}' has type "
                  "'${factoryParamType.getDisplayString()}' but the "
                  'corresponding @assisted parameter '
                  "'${targetParam.name}' has type "
                  "'${targetParamType.getDisplayString()}'.",
              suggestion:
                  'Align the factory method parameter types with the '
                  '@assisted parameter types of the target constructor.',
            );
            return null;
          }
        }
      }
    } else {
      reporter.errorForElement(
        createMethod,
        message:
            "Factory method '${createMethod.name}' returns "
            "'${targetType.getDisplayString()}' which is not a class type.",
        suggestion:
            'The factory method must return the type of the '
            '@assistedInject target class.',
      );
      return null;
    }

    final assistedParameters = <ParameterDependency>[];
    for (final FormalParameterElement param in createMethod.formalParameters) {
      assistedParameters.add((parameter: param, type: param.type, qualifier: param.readQualifier(), isProvider: false));
    }

    return (
      factoryElement: classElement,
      createMethod: createMethod,
      targetType: targetType,
      targetQualifier: targetQualifier,
      assistedParameters: assistedParameters,
    );
  }
}
