import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports every entry point of a component after the first one.
///
/// An entry point is a getter or method that is abstract or annotated with
/// `@inject`, which is how inject.dart itself finds them.
///
/// shortcut: entry points inherited from a supertype are not counted. Upgrade
/// if components start to share entry points through interfaces.
class PreferSingleEntryPoint extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_single_entry_point',
    "The component '{0}' exposes more than one type.",
    correctionMessage:
        'Expose one type, for example the factory of the root widget, and let '
        'that type get everything else through injection.',
  );

  PreferSingleEntryPoint()
    : super(name: 'prefer_single_entry_point', description: 'A component should expose only one type.');

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
    if (!hasAnnotation(node.declaredFragment?.element, const {'Component', 'Subcomponent'})) return;
    final ClassBody body = node.body;
    if (body is! BlockClassBody) return;

    final Iterable<MethodDeclaration> entryPoints = body.members.whereType<MethodDeclaration>().where(_isEntryPoint);
    for (final MethodDeclaration entryPoint in entryPoints.skip(1)) {
      rule.reportAtToken(entryPoint.name, arguments: [node.namePart.typeName.lexeme]);
    }
  }

  bool _isEntryPoint(MethodDeclaration member) {
    if (member.isStatic || member.isSetter || member.isOperator) return false;
    final ExecutableElement? element = member.declaredFragment?.element;
    return element != null && (element.isAbstract || hasAnnotation(element, const {'Inject'}));
  }
}
