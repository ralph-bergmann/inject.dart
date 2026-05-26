import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import '../validation/binding_key.dart';
import 'type_checkers.dart';

/// Binding metadata extracted from method-level annotations.
typedef BindingMetadata = ({
  bool isSingleton,
  bool isAsynchronous,
  bool isProvisionListener,
  DartType? listenerTypeArgument,
  String? qualifier,
});

/// A single provider method descriptor from a `@module` class.
typedef ProviderDescriptor = ({
  BindingKey key,
  MethodElement method,
  DartType returnType,
  List<ParameterDependency> dependencies,
  BindingMetadata metadata,
});

/// A parameter dependency with optional qualifier.
typedef ParameterDependency = ({FormalParameterElement parameter, DartType type, String? qualifier, bool isProvider});

/// Result of reading a `@module`-annotated class.
typedef ModuleData = ({List<ProviderDescriptor> providers, bool hasDefaultConstructor});

/// Reads `@module`-annotated classes and extracts `@provides` method
/// descriptors with their return types, dependencies, and binding metadata.
class ModuleReader {
  /// Creates a [ModuleReader] reporting through [reporter].
  ModuleReader({required this.reporter});

  /// The diagnostic sink for reporting errors and warnings.
  final DiagnosticReporter reporter;

  /// Extracts the type argument `T` from `ProvisionListener<T>`.
  ///
  /// Returns `null` for catch-all listeners (`ProvisionListener<Object>` or
  /// raw `ProvisionListener`), meaning the listener fires for all provisions.
  /// Returns the concrete [DartType] for type-scoped listeners.
  static DartType? _extractListenerTypeArgument(DartType returnType) {
    if (returnType case final InterfaceType interfaceType) {
      for (final InterfaceType type in [interfaceType, ...interfaceType.allSupertypes]) {
        if (provisionListenerInterfaceChecker.isExactlyType(type)) {
          final List<DartType> typeArgs = type.typeArguments;
          if (typeArgs.isNotEmpty && !typeArgs.first.isDartCoreObject && typeArgs.first is! DynamicType) {
            return typeArgs.first;
          }
          return null;
        }
      }
    }
    return null;
  }

  /// Reads the `@module` class and returns extracted [ModuleData].
  ModuleData readModule(ClassElement classElement) {
    final providers = <ProviderDescriptor>[];

    for (final MethodElement method in classElement.methods) {
      if (!providesChecker.hasAnnotationOf(method)) {
        continue;
      }

      final bool isSingleton = singletonChecker.hasAnnotationOf(method);
      final bool isAsynchronous = asynchronousChecker.hasAnnotationOf(method);
      bool isProvisionListener = provisionListenerChecker.hasAnnotationOf(method);
      final String? qualifier = method.readQualifier();

      // Validate @provisionListener usage
      if (isProvisionListener) {
        final DartType returnType = method.returnType;
        if (!provisionListenerInterfaceChecker.isAssignableFromType(returnType)) {
          reporter.errorForElement(
            method,
            message:
                "Method '${classElement.name}.${method.name}' is annotated with "
                "@provisionListener but returns '${returnType.getDisplayString()}' "
                'which does not implement ProvisionListener.',
            suggestion:
                'Change the return type to a class that implements ProvisionListener, '
                'or remove the @provisionListener annotation.',
          );
          isProvisionListener = false;
        }
        if (!isSingleton) {
          reporter.infoForElement(
            method,
            message:
                "Provider '${classElement.name}.${method.name}' is annotated with "
                '@provisionListener without @singleton — it will be treated as '
                'a singleton automatically.',
            suggestion:
                'You can add @singleton explicitly to silence this notice, '
                'but it is not required.',
          );
        }
      }

      final dependencies = <ParameterDependency>[];
      for (final FormalParameterElement param in method.formalParameters) {
        dependencies.add((parameter: param, type: param.type, qualifier: param.readQualifier(), isProvider: false));
      }

      // When @asynchronous, unwrap Future<T> to use T for the binding key.
      // The original Future<T> return type is preserved in ProviderDescriptor
      // for code generation.
      final DartType keyType = isAsynchronous ? method.returnType.unwrapFuture : method.returnType;

      final BindingKey? key = BindingKey.fromDartType(keyType, qualifier: qualifier);
      if (key == null) {
        final String typeDescription = switch (keyType) {
          RecordType() => 'Record type',
          FunctionType() => 'Function type',
          _ => "Unsupported type '${keyType.getDisplayString()}'",
        };

        reporter.errorForElement(
          method,
          message:
              '$typeDescription is not supported as a provider return type '
              "in '${classElement.name}.${method.name}'.",
          suggestion: 'Use an interface type or wrap the dependency in a typedef or class.',
        );
        continue;
      }

      providers.add((
        key: key,
        method: method,
        returnType: method.returnType,
        dependencies: dependencies,
        metadata: (
          isSingleton: isSingleton,
          isAsynchronous: isAsynchronous,
          isProvisionListener: isProvisionListener,
          listenerTypeArgument: isProvisionListener ? _extractListenerTypeArgument(method.returnType) : null,
          qualifier: qualifier,
        ),
      ));
    }

    final bool hasDefaultConstructor = _computeHasDefaultConstructor(classElement);
    return (providers: providers, hasDefaultConstructor: hasDefaultConstructor);
  }

  /// Returns `true` when the module class has a public unnamed constructor
  /// that can be called with no arguments (i.e. `Module()` is valid Dart).
  ///
  /// Returns `false` for abstract classes, generic classes, classes with no
  /// unnamed constructor, private constructors, and constructors with
  /// required parameters.
  static bool _computeHasDefaultConstructor(ClassElement cls) {
    if (cls.isAbstract) {
      return false;
    }
    // Generic classes need type arguments at the call site; the generated
    // `Module()` fallback would lack them and infer `dynamic`.
    if (cls.typeParameters.isNotEmpty) {
      return false;
    }
    final ConstructorElement? ctor = cls.unnamedConstructor;
    if (ctor == null) {
      return false;
    }
    if (!ctor.isPublic) {
      return false;
    }
    return ctor.formalParameters.every(
      (p) => !p.isRequiredPositional && !p.isRequiredNamed,
    );
  }
}
