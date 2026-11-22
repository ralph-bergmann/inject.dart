import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports an `@assistedFactory` or `@subcomponentFactory` class that the
/// generator rejects.
class RequireValidFactory extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_valid_factory',
    '{0}',
    correctionMessage: '{1} $assistedInjectionSkill',
    severity: DiagnosticSeverity.ERROR,
  );

  RequireValidFactory()
    : super(
        name: 'require_valid_factory',
        description: 'An @assistedFactory or @subcomponentFactory class must be a valid factory.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final ClassElement? element = node.declaredFragment?.element;
    final bool assisted = hasAnnotation(element, const {'AssistedFactory'});
    if (element == null || !(assisted || hasAnnotation(element, const {'SubcomponentFactory'}))) return;

    void report(String problem, String correction) =>
        rule.reportAtToken(node.namePart.typeName, arguments: [problem, correction]);

    final String name = element.name ?? '';
    if (!element.isAbstract) {
      return report("The factory '$name' must be abstract.", "Add the 'abstract' modifier.");
    }
    final List<MethodElement> abstractMethods = element.methods.where((m) => m.isAbstract).toList();
    if (abstractMethods.length != 1) {
      return report(
        "The factory '$name' has ${abstractMethods.length} abstract methods.",
        'A factory must have exactly one abstract method, which creates the object.',
      );
    }

    final MethodElement create = abstractMethods.single;
    final DartType returnType = create.returnType;
    final ClassElement? target = returnType is InterfaceType && returnType.element is ClassElement
        ? returnType.element as ClassElement
        : null;
    final String? problem = assisted ? _assistedProblem(create, target) : _subcomponentProblem(create, target);
    if (problem != null) {
      report(problem, assisted ? "Match the target's '@assistedInject' constructor." : 'Return the subcomponent.');
    }
  }

  String? _assistedProblem(MethodElement create, ClassElement? target) {
    final String returned = create.returnType.getDisplayString();
    if (target == null) return "The factory method '${create.name}' returns '$returned', which is not a class.";

    final List<ConstructorElement> constructors = target.constructors
        .where((c) => hasAnnotation(c, const {'AssistedInject'}))
        .toList();
    final String? qualifier = readQualifier(create);
    if (qualifier == null && constructors.length > 1) {
      return "The class '$returned' has several '@assistedInject' constructors, "
          "and the factory method '${create.name}' has no qualifier to pick one.";
    }
    final ConstructorElement? constructor = qualifier == null
        ? constructors.firstOrNull
        : constructors.where((c) => readQualifier(c) == qualifier).firstOrNull;
    if (constructor == null) {
      return "The class '$returned' has no '@assistedInject' constructor"
          "${qualifier == null ? '' : " with the qualifier '$qualifier'"}.";
    }

    final List<FormalParameterElement> assistedParameters = constructor.formalParameters
        .where((p) => hasAnnotation(p, const {'Assisted'}))
        .toList();
    final List<FormalParameterElement> factoryParameters = create.formalParameters;
    if (factoryParameters.length != assistedParameters.length) {
      return "The factory method '${create.name}' has ${factoryParameters.length} parameters, "
          'but the constructor has ${assistedParameters.length} @assisted parameters.';
    }

    final Iterator<FormalParameterElement> positional = factoryParameters.where((p) => !p.isNamed).iterator;
    for (final FormalParameterElement expected in assistedParameters) {
      final FormalParameterElement? actual = expected.isNamed
          ? factoryParameters.where((p) => p.isNamed && p.name == expected.name).firstOrNull
          : (positional.moveNext() ? positional.current : null);
      if (actual == null) {
        return "The factory method '${create.name}' has no parameter for '${expected.name}'.";
      }
      if (actual.type != expected.type) {
        return "The parameter '${actual.name}' has the type '${actual.type.getDisplayString()}', "
            "but the @assisted parameter '${expected.name}' has the type '${expected.type.getDisplayString()}'.";
      }
    }
    return null;
  }

  String? _subcomponentProblem(MethodElement create, ClassElement? target) {
    if (!hasAnnotation(target, const {'Subcomponent'})) {
      return "The factory method '${create.name}' returns '${create.returnType.getDisplayString()}', "
          "which is not annotated with '@subcomponent'.";
    }
    final types = <DartType>{};
    for (final FormalParameterElement parameter in create.formalParameters) {
      if (hasAnnotation(parameter.type.element, const {'Module'}) && !types.add(parameter.type)) {
        return "The factory method '${create.name}' takes the module '${parameter.type.getDisplayString()}' twice.";
      }
    }
    return null;
  }
}
