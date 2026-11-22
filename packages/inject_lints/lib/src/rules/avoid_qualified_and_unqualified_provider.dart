import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports an unqualified provider in a module that also provides the same
/// type with a qualifier. That is usually a forgotten qualifier.
class AvoidQualifiedAndUnqualifiedProvider extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_qualified_and_unqualified_provider',
    "The module provides '{0}' both with and without a qualifier.",
    correctionMessage:
        'Add a qualifier to this provider, or ignore the warning if both bindings are intended. $createModuleSkill',
    severity: DiagnosticSeverity.WARNING,
  );

  AvoidQualifiedAndUnqualifiedProvider()
    : super(
        name: 'avoid_qualified_and_unqualified_provider',
        description: 'A module should not provide the same type with and without a qualifier.',
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

    final unqualified = <DartType, MethodDeclaration>{};
    final qualified = <DartType>{};
    for (final MethodDeclaration method in body.members.whereType<MethodDeclaration>()) {
      final ExecutableElement? element = method.declaredFragment?.element;
      if (element == null || !hasAnnotation(element, const {'Provides'})) continue;
      if (hasAnnotation(element, const {'ProvisionListenerAnnotation'})) continue;

      final DartType returnType = element.returnType;
      // The binding of an asynchronous provider is the type inside the Future.
      final DartType type =
          hasAnnotation(element, const {'Asynchronous'}) && returnType is InterfaceType && returnType.isDartAsyncFuture
          ? returnType.typeArguments.single
          : returnType;
      if (readQualifier(element) == null) {
        unqualified[type] = method;
      } else {
        qualified.add(type);
      }
    }

    for (final MapEntry(key: type, value: method) in unqualified.entries) {
      if (qualified.contains(type)) rule.reportAtToken(method.name, arguments: [type.getDisplayString()]);
    }
  }
}
