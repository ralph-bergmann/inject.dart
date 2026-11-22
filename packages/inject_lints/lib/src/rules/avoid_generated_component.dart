import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a reference to the generated `X$Component` class outside the
/// component class `X` itself.
class AvoidGeneratedComponent extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_generated_component',
    "Do not use the generated class '{0}' directly.",
    correctionMessage:
        "Declare 'static const create = {0}.create;' in '{1}' and call "
        "'{1}.create(...)'. Generated names then stay out of your code. $setupSkill",
  );

  AvoidGeneratedComponent()
    : super(
        name: 'avoid_generated_component',
        description: "Create a component through its own 'create', not through the generated class.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addNamedType(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitNamedType(NamedType node) {
    // The name check comes first because this runs for every type in a file.
    if (!node.name.lexeme.endsWith(r'$Component')) return;
    final Element? generated = node.element;
    if (generated is! ClassElement) return;
    // The generated library refers to its own class; that is not user code.
    if (generated.library == context.libraryElement) return;

    final InterfaceElement? component = generated.interfaces
        .map((InterfaceType type) => type.element)
        .where((element) => hasAnnotation(element, const {'Component'}))
        .firstOrNull;
    if (component == null) return;

    final ClassDeclaration? enclosing = node.thisOrAncestorOfType<ClassDeclaration>();
    if (enclosing?.declaredFragment?.element == component) return;

    // The source keeps an import prefix, so the suggested line can be copied.
    rule.reportAtNode(node, arguments: [node.toSource(), component.name ?? '']);
  }
}
