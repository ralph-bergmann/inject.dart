import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/assisted_reader.dart';
import '../extensions/dart_type_extensions.dart';
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
