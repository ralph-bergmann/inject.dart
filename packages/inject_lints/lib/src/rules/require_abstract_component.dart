import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a `@Component` or `@Subcomponent` class that is not `abstract`.
class RequireAbstractComponent extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_abstract_component',
    "The component class '{0}' must be abstract.",
    correctionMessage: "Add the 'abstract' modifier. inject.dart generates the implementation. $setupSkill",
    severity: DiagnosticSeverity.WARNING,
  );

  RequireAbstractComponent()
    : super(name: 'require_abstract_component', description: 'A @Component or @Subcomponent class must be abstract.');

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
    if (node.abstractKeyword != null) return;
    if (!hasAnnotation(node.declaredFragment?.element, const {'Component', 'Subcomponent'})) return;
    rule.reportAtToken(node.namePart.typeName, arguments: [node.namePart.typeName.lexeme]);
  }
}
