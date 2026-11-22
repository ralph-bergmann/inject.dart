import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a `@provides` method that only forwards its own parameters to the
/// constructor of a class from the same package.
///
/// Such a class can carry `@inject` itself. A provider that adds something of
/// its own stays allowed: a module field, a literal, an interface as return
/// type, `@asynchronous` or `@provisionListener`.
///
/// shortcut: a provider that scopes a singleton to a subcomponent looks the
/// same and is reported too. Suppress it there with an `ignore` comment.
class PreferInjectOverProvides extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_inject_over_provides',
    "'{0}' only forwards its parameters to the constructor of '{1}'.",
    correctionMessage:
        "Annotate '{1}' with '@inject' and remove this provider. Keep '@singleton' "
        "on the class if the provider has it. Modules are for types you cannot "
        "annotate. $createModuleSkill",
  );

  PreferInjectOverProvides()
    : super(
        name: 'prefer_inject_over_provides',
        description: 'A module should not provide a type that can carry @inject itself.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final ExecutableElement? method = node.declaredFragment?.element;
    if (!hasAnnotation(method, const {'Provides'})) return;
    // Only a provider can be asynchronous or a provision listener.
    if (hasAnnotation(method, const {'Asynchronous', 'ProvisionListenerAnnotation'})) return;

    final Expression? returned = _returnedExpression(node.body);
    if (returned is! InstanceCreationExpression) return;

    final Element? created = returned.constructorName.type.element;
    if (created is! ClassElement) return;
    // A wider return type binds an interface to this implementation.
    if (method!.returnType.element != created) return;
    if (!_isInThisPackage(created)) return;

    final bool forwardsOnly = returned.argumentList.arguments.every((Argument argument) {
      final Expression value = argument.argumentExpression;
      return value is SimpleIdentifier && method.formalParameters.contains(value.element);
    });
    if (!forwardsOnly) return;

    rule.reportAtToken(node.name, arguments: [node.name.lexeme, created.name ?? '']);
  }

  Expression? _returnedExpression(FunctionBody body) {
    if (body is ExpressionFunctionBody) return body.expression;
    if (body is BlockFunctionBody && body.block.statements.length == 1) {
      final Statement statement = body.block.statements.single;
      if (statement is ReturnStatement) return statement.expression;
    }
    return null;
  }

  bool _isInThisPackage(ClassElement element) {
    final package = context.package;
    return package != null && package.contains(element.library.firstFragment.source);
  }
}
