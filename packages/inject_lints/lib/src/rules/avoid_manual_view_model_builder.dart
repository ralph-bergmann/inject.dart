import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a `ViewModelBuilder` that is constructed by hand.
class AvoidManualViewModelBuilder extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_manual_view_model_builder',
    "Do not construct 'ViewModelBuilder' by hand.",
    correctionMessage:
        "Inject a 'ViewModelFactory<T>' and call it. It returns the "
        "'ViewModelBuilder' with the view model from the graph. $viewModelSkill",
  );

  AvoidManualViewModelBuilder()
    : super(
        name: 'avoid_manual_view_model_builder',
        description: 'Get a ViewModelBuilder from an injected ViewModelFactory.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final Element? created = node.constructorName.type.element;
    if (created == null || created.name != 'ViewModelBuilder' || !isFromPackage(created, 'inject_flutter')) return;
    rule.reportAtNode(node.constructorName);
  }
}
