import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a class with `@inject` or `@assistedInject` that is constructed by
/// hand instead of taken from the dependency graph.
class AvoidConstructingInjectedClass extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_constructing_injected_class',
    "Do not construct the injected class '{0}' by hand.",
    correctionMessage:
        "Inject '{0}', a 'Provider<{0}>' or its factory instead. The graph then "
        'supplies the dependencies and keeps the scope. $setupSkill',
  );

  AvoidConstructingInjectedClass()
    : super(
        name: 'avoid_constructing_injected_class',
        description: 'Take an injected class from the dependency graph instead of constructing it.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isExcludedFromRule(context, name)) return;
    // The generated code is the one place that must construct the class.
    if (context.definingUnit.file.path.endsWith('.inject.dart')) return;
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final InterfaceElement? created = node.constructorName.element?.enclosingElement;
    if (created == null || !isInjected(created)) return;
    // A class may construct itself, for example in a factory constructor.
    final ClassDeclaration? enclosing = node.thisOrAncestorOfType<ClassDeclaration>();
    if (enclosing?.declaredFragment?.element == created) return;
    rule.reportAtNode(node.constructorName, arguments: [created.name ?? '']);
  }
}
