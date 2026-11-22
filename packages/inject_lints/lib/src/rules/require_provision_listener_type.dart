import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a `@provisionListener` method whose return type does not
/// implement `ProvisionListener`.
class RequireProvisionListenerType extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_provision_listener_type',
    "The '@provisionListener' method returns '{0}', which does not implement 'ProvisionListener'.",
    correctionMessage:
        "Return a class that implements 'ProvisionListener', or remove '@provisionListener'. $createModuleSkill",
    severity: DiagnosticSeverity.ERROR,
  );

  RequireProvisionListenerType()
    : super(
        name: 'require_provision_listener_type',
        description: 'A @provisionListener method must return a ProvisionListener.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final ExecutableElement? element = node.declaredFragment?.element;
    if (element == null || !hasAnnotation(element, const {'ProvisionListenerAnnotation'})) return;
    final DartType type = element.returnType;
    if (type is InterfaceType && [type, ...type.allSupertypes].any(_isProvisionListener)) return;
    rule.reportAtNode(node.returnType ?? node, arguments: [type.getDisplayString()]);
  }

  bool _isProvisionListener(InterfaceType type) =>
      type.element.name == 'ProvisionListener' && isFromPackage(type.element, 'inject_annotation');
}
