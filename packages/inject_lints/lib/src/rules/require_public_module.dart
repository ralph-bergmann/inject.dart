import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a private `@module` class, which the generated component, a
/// separate library, cannot create.
class RequirePublicModule extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_public_module',
    "The module class '{0}' must be public.",
    correctionMessage: "Remove the leading underscore. $createModuleSkill",
    severity: DiagnosticSeverity.ERROR,
  );

  RequirePublicModule() : super(name: 'require_public_module', description: 'A @module class must be public.');

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
    final name = node.namePart.typeName;
    if (!name.lexeme.startsWith('_')) return;
    if (!hasAnnotation(node.declaredFragment?.element, const {'Module'})) return;
    rule.reportAtToken(name, arguments: [name.lexeme]);
  }
}
