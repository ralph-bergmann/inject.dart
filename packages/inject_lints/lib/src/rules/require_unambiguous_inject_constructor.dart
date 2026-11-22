import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a class whose injected constructor the generator cannot pick.
///
/// Several `@inject` or `@assistedInject` constructors each need a unique
/// `@Qualifier`, and `@inject` on a class with several constructors needs an
/// unnamed one.
class RequireUnambiguousInjectConstructor extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_unambiguous_inject_constructor',
    '{0}',
    correctionMessage: '{1} $setupSkill',
    severity: DiagnosticSeverity.ERROR,
  );

  RequireUnambiguousInjectConstructor()
    : super(
        name: 'require_unambiguous_inject_constructor',
        description: 'inject.dart must be able to pick the injected constructor of a class.',
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
    final ClassElement? element = node.declaredFragment?.element;
    if (element == null) return;
    final String name = element.name ?? '';

    void report(String problem, String correction) =>
        rule.reportAtToken(node.namePart.typeName, arguments: [problem, correction]);

    for (final String annotation in const ['Inject', 'AssistedInject']) {
      final List<ConstructorElement> annotated = element.constructors
          .where((c) => hasAnnotation(c, {annotation}))
          .toList();
      if (annotated.length < 2) continue;

      final label = annotation == 'Inject' ? '@inject' : '@assistedInject';
      final qualifiers = <String>{};
      for (final ConstructorElement constructor in annotated) {
        final String? qualifier = readQualifier(constructor);
        if (qualifier == null) {
          return report(
            "The class '$name' has several '$label' constructors without a qualifier.",
            "Add a unique '@Qualifier' to each '$label' constructor, or keep '$label' on one constructor.",
          );
        }
        if (!isValidQualifier(qualifier)) {
          return report(
            "The qualifier '$qualifier' on a constructor of '$name' is no valid identifier.",
            'Use only letters, digits and underscores in the qualifier.',
          );
        }
        if (!qualifiers.add(qualifier)) {
          return report(
            "Two '$label' constructors of '$name' have the qualifier '$qualifier'.",
            "Give each '$label' constructor its own '@Qualifier'.",
          );
        }
      }
    }

    final bool classInjected = hasAnnotation(element, const {'Inject'});
    final bool constructorInjected = element.constructors.any((c) => hasAnnotation(c, const {'Inject'}));
    if (classInjected &&
        !constructorInjected &&
        element.constructors.length > 1 &&
        element.unnamedConstructor == null) {
      report(
        "The class '$name' has several constructors, and none is annotated with '@inject'.",
        "Annotate the constructor to use with '@inject'.",
      );
    }
  }
}
