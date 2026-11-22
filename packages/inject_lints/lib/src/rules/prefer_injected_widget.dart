import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a public widget whose constructor takes a type from the dependency
/// graph, although the widget itself is not injected.
///
/// A widget that only takes plain values and callbacks, such as a button of a
/// design system, has no such parameter and is never reported.
class PreferInjectedWidget extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_injected_widget',
    "The widget '{0}' takes '{1}' from the dependency graph but is not injected itself.",
    correctionMessage:
        "Annotate the constructor with '@assistedInject' and mark the parameters "
        "that the caller passes, such as 'key', with '@assisted'. $assistedInjectionSkill",
  );

  PreferInjectedWidget()
    : super(
        name: 'prefer_injected_widget',
        description: 'A public widget that takes injectable types should be created through injection.',
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
    final ClassElement? widget = node.declaredFragment?.element;
    if (widget == null || widget.isPrivate || widget.isAbstract) return;
    if (!extendsFlutterClass(widget, 'Widget') || isInjected(widget)) return;

    final FormalParameterElement? dependency = widget.constructors
        .expand((ConstructorElement constructor) => constructor.formalParameters)
        .where((FormalParameterElement parameter) => isGraphType(parameter.type))
        .firstOrNull;
    if (dependency == null) return;

    // The message names the parameter, not its type: a 'ViewModelFactory'
    // prints as a long function type.
    rule.reportAtToken(node.namePart.typeName, arguments: [node.namePart.typeName.lexeme, dependency.name ?? '']);
  }
}
