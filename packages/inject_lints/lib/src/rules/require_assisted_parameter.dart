import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports an `@assistedInject` constructor without an `@assisted` parameter.
class RequireAssistedParameter extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_assisted_parameter',
    "The '@assistedInject' constructor has no '@assisted' parameter.",
    correctionMessage:
        "Mark the parameters the caller passes with '@assisted', or use '@inject' instead. "
        '$assistedInjectionSkill',
    severity: DiagnosticSeverity.ERROR,
  );

  RequireAssistedParameter()
    : super(
        name: 'require_assisted_parameter',
        description: 'An @assistedInject constructor must have at least one @assisted parameter.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addConstructorDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || !hasAnnotation(element, const {'AssistedInject'})) return;
    if (element.formalParameters.any((p) => hasAnnotation(p, const {'Assisted'}))) return;
    rule.reportAtNode(node.parameters);
  }
}
