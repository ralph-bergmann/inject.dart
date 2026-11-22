import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a public instance method of a `@module` class without `@provides`.
///
/// inject.dart skips such a method without a message, so the binding is
/// missing from the graph.
class RequireProvidesAnnotation extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_provides_annotation',
    "The module method '{0}' has no '@provides' annotation.",
    correctionMessage:
        "Add '@provides', or make the method private if it is a helper. "
        'inject.dart ignores a module method without it. $createModuleSkill',
    severity: DiagnosticSeverity.WARNING,
  );

  RequireProvidesAnnotation()
    : super(
        name: 'require_provides_annotation',
        description: 'A public method of a @module class must be annotated with @provides.',
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
    if (!hasAnnotation(node.declaredFragment?.element, const {'Module'})) return;
    final ClassBody body = node.body;
    if (body is! BlockClassBody) return;

    for (final MethodDeclaration member in body.members.whereType<MethodDeclaration>()) {
      if (member.isStatic || member.isGetter || member.isSetter || member.isOperator) continue;
      if (member.name.lexeme.startsWith('_')) continue;
      if (hasAnnotation(member.declaredFragment?.element, const {'Provides'})) continue;
      rule.reportAtToken(member.name, arguments: [member.name.lexeme]);
    }
  }
}
