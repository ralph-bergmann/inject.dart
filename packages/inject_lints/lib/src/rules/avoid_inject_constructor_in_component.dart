import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports an `@inject` or `@assistedInject` constructor in a `@Component`
/// class. inject.dart generates the component, so it has no injected
/// constructor.
class AvoidInjectConstructorInComponent extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_inject_constructor_in_component',
    'A component class must not have an injected constructor.',
    correctionMessage:
        'Move the constructor to a separate class that the component exposes, or remove '
        "'@Component' if the class is meant to be injected. $setupSkill",
    severity: DiagnosticSeverity.ERROR,
  );

  AvoidInjectConstructorInComponent()
    : super(
        name: 'avoid_inject_constructor_in_component',
        description: 'A @Component class must not have an @inject or @assistedInject constructor.',
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
    if (element == null || !hasAnnotation(element, const {'Inject', 'AssistedInject'})) return;
    if (!hasAnnotation(element.enclosingElement, const {'Component'})) return;
    rule.reportAtNode(node.typeName ?? node);
  }
}
