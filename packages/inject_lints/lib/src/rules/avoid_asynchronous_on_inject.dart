import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports `@asynchronous` on an injected class or constructor, where
/// inject.dart ignores it.
class AvoidAsynchronousOnInject extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_asynchronous_on_inject',
    "'@asynchronous' has no effect on an injected class or constructor.",
    correctionMessage:
        "Remove '@asynchronous'. For a provider that must wait, use an '@asynchronous' '@provides' method in a module. "
        '$createModuleSkill',
    severity: DiagnosticSeverity.WARNING,
  );

  AvoidAsynchronousOnInject()
    : super(name: 'avoid_asynchronous_on_inject', description: '@asynchronous only works on @provides methods.');

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
    final ClassElement? element = node.declaredFragment?.element;
    if (element == null) return;
    final List<ConstructorElement> injected = element.constructors
        .where((c) => hasAnnotation(c, const {'Inject'}))
        .toList();
    // The generator warns only when the class is injectable at all.
    if (injected.isEmpty && !hasAnnotation(element, const {'Inject'})) return;

    _reportOn(node.metadata);
    final ClassBody body = node.body;
    if (body is! BlockClassBody) return;
    for (final ConstructorDeclaration constructor in body.members.whereType<ConstructorDeclaration>()) {
      if (injected.contains(constructor.declaredFragment?.element)) _reportOn(constructor.metadata);
    }
  }

  void _reportOn(NodeList<Annotation> metadata) {
    for (final Annotation annotation in metadata) {
      final Element? type = annotation.elementAnnotation?.computeConstantValue()?.type?.element;
      if (type?.name == 'Asynchronous' && isFromPackage(type!, 'inject_annotation')) rule.reportAtNode(annotation);
    }
  }
}
