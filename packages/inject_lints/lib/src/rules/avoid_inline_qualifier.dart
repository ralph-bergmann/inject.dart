import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports `@Qualifier(#name)` written directly as an annotation.
class AvoidInlineQualifier extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_inline_qualifier',
    "Do not write 'Qualifier(...)' directly as an annotation.",
    correctionMessage:
        "Declare a constant, for example 'const baseUrl = Qualifier(#baseUrl);', "
        "and annotate with '@baseUrl'. The provider and every injection site "
        'then share one symbol. $createModuleSkill',
  );

  AvoidInlineQualifier()
    : super(
        name: 'avoid_inline_qualifier',
        description: 'Use a constant for a Qualifier instead of an inline constructor call.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addAnnotation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitAnnotation(Annotation node) {
    final Element? constructor = node.elementAnnotation?.element;
    if (constructor is! ConstructorElement) return;
    final InterfaceElement qualifier = constructor.enclosingElement;
    if (qualifier.name != 'Qualifier' || !isFromPackage(qualifier, 'inject_annotation')) return;
    rule.reportAtNode(node);
  }
}
