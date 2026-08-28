import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/assisted_reader.dart';
import '../analysis/module_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../extensions/string_extensions.dart';
import 'naming.dart';

/// Generates the public abstract factory class for a synthesized
/// `@assistedInject` constructor (one without an explicit `@assistedFactory`).
///
/// The concrete factory implementation lives in `.inject.dart`
/// (`_<FactoryName>$Factory` via `ProviderGenerator.generateInlineFactory`);
/// nothing in `.factory.dart` references the abstract class beyond declaring
/// it for user code.
class FactoryGenerator {
  /// Generates the public abstract factory class for a single
  /// `@assistedInject` constructor that has no explicit `@assistedFactory`.
  ///
  /// The abstract class:
  /// - Is public so users can reference it in modules and components
  /// - Single-ctor: `<ClassName>Factory`; multi-ctor: `<ClassName><Qualifier>Factory`
  /// - Has exactly one abstract `create(...)` method
  ///
  /// [isMulti] must be `true` when the class has more than one `@assistedInject`
  /// constructor so the qualifier suffix is applied to the class name.
  Class generateSynthesizedAbstractFactory({
    required AssistedInjectData injectData,
    bool isMulti = false,
  }) {
    final String targetClassName = injectData.constructor.enclosingElement.name!;
    final String? factoryQualifier = isMulti ? injectData.key.qualifier : null;
    final String abstractClassName = synthesizedFactoryClassName(
      targetClassName,
      factoryQualifier,
    );

    final Reference returnTypeRef = injectData.constructor.enclosingElement.thisType.typeRef();

    final (:List<Parameter> requiredCreateParams, :List<Parameter> optionalCreateParams) = _buildCreateParams(
      [for (final ap in injectData.assistedParameters) ap.parameter],
    );

    return Class(
      (b) => b
        ..name = abstractClassName
        ..abstract = true
        ..methods.add(
          Method(
            (b) => b
              ..name = 'create'
              ..returns = returnTypeRef
              ..requiredParameters.addAll(requiredCreateParams)
              ..optionalParameters.addAll(optionalCreateParams),
          ),
        ),
    );
  }

  /// Generates the public abstract factory class for a `@subcomponent`.
  ///
  /// The abstract class is what user code references (module providers,
  /// component entry points); the concrete implementation
  /// (`_<FactoryName>$Factory`) is generated into the parent component's
  /// `.inject.dart`. The `create(...)` method takes one named parameter per
  /// subcomponent module, `required` when the module has no accessible
  /// no-arg constructor — mirroring the generated component `create(...)`.
  Class generateSubcomponentAbstractFactory({
    required ClassElement subcomponentClass,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
  }) {
    final String subcomponentName = subcomponentClass.name!;
    final String abstractClassName = subcomponentFactoryClassName(subcomponentName);
    final Reference returnTypeRef = subcomponentClass.thisType.typeRef();

    final params = <Parameter>[];
    for (final m in modules) {
      final bool hasDefaultCtor = m.moduleData.hasDefaultConstructor;
      final Reference moduleTypeRef = m.moduleClass.thisType.typeRef();
      params.add(
        Parameter(
          (b) => b
            ..name = m.moduleClass.name!.uncapitalize
            ..named = true
            ..required = !hasDefaultCtor
            ..type = TypeReference(
              (b) => b
                ..symbol = (moduleTypeRef as TypeReference).symbol
                ..url = moduleTypeRef.url
                ..isNullable = hasDefaultCtor,
            ),
        ),
      );
    }

    return Class(
      (b) => b
        ..name = abstractClassName
        ..abstract = true
        ..methods.add(
          Method(
            (b) => b
              ..name = 'create'
              ..returns = returnTypeRef
              ..optionalParameters.addAll(params),
          ),
        ),
    );
  }

  /// Partitions [parameters] into required-positional vs the rest
  /// (optional-positional / named-required / named-optional) and emits
  /// matching code_builder [Parameter] specs. The partition mirrors Dart's
  /// formal-parameter kinds so optional-positional params end up in
  /// [Method.optionalParameters] rather than [Method.requiredParameters].
  static ({List<Parameter> requiredCreateParams, List<Parameter> optionalCreateParams}) _buildCreateParams(
    List<FormalParameterElement> parameters,
  ) {
    final requiredCreateParams = <Parameter>[];
    final optionalCreateParams = <Parameter>[];
    for (final param in parameters) {
      final spec = Parameter((b) {
        b
          ..name = param.name!
          ..type = param.type.typeRef();
        if (param.isNamed) {
          b.named = true;
          if (param.isRequired) {
            b.required = true;
          }
        }
      });
      if (param.isRequiredPositional) {
        requiredCreateParams.add(spec);
      } else {
        optionalCreateParams.add(spec);
      }
    }
    return (requiredCreateParams: requiredCreateParams, optionalCreateParams: optionalCreateParams);
  }
}
