import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../inject.dart';

/// Reports a wrong entry in the module list of `@Component` or
/// `@Subcomponent`, or in `includes` or `subcomponents` of `@Module`.
class RequireValidModuleList extends AnalysisRule {
  static const LintCode code = LintCode(
    'require_valid_module_list',
    '{0}',
    correctionMessage: '{1} $createModuleSkill',
    severity: DiagnosticSeverity.ERROR,
  );

  RequireValidModuleList()
    : super(
        name: 'require_valid_module_list',
        description: 'The module and subcomponent lists of inject.dart annotations must be valid.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addAnnotation(this, _Visitor(this));
  }
}

/// What a list may hold: the annotation class, its list field, and whether
/// the entries must be modules or subcomponents.
typedef _ListSpec = ({String annotation, String field, bool wantsSubcomponents});

const _specs = <_ListSpec>[
  (annotation: 'Component', field: 'modules', wantsSubcomponents: false),
  (annotation: 'Subcomponent', field: 'modules', wantsSubcomponents: false),
  (annotation: 'Module', field: 'includes', wantsSubcomponents: false),
  (annotation: 'Module', field: 'subcomponents', wantsSubcomponents: true),
];

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitAnnotation(Annotation node) {
    final DartObject? value = node.elementAnnotation?.computeConstantValue();
    final Element? type = value?.type?.element;
    if (value == null || type == null || !isFromPackage(type, 'inject_annotation')) return;

    for (final _ListSpec spec in _specs.where((s) => s.annotation == type.name)) {
      final List<DartObject> entries = value.getField(spec.field)?.toListValue() ?? const [];
      final List<CollectionElement>? literal = _literal(node, spec)?.elements;
      final seen = <Element>{};
      for (var i = 0; i < entries.length; i++) {
        final Element? entry = entries[i].toTypeValue()?.element;
        // An unresolved entry already gets a compile error.
        if (entry == null) continue;
        final (String, String)? problem = _problem(entry, spec, type.name!, seen);
        if (problem == null) continue;
        final AstNode at = literal != null && literal.length == entries.length ? literal[i] : node;
        rule.reportAtNode(at, arguments: [problem.$1, problem.$2]);
      }
    }
  }

  /// The problem with [entry] and how to fix it, or `null`.
  (String, String)? _problem(Element entry, _ListSpec spec, String annotation, Set<Element> seen) {
    final String list = annotation == 'Module' ? '@Module(${spec.field}: ...)' : '@$annotation([...])';
    const addAnnotation = 'Remove the entry, or add the missing annotation to its class.';
    if (!seen.add(entry)) return ("'${entry.name}' is listed more than once in $list.", 'Remove the duplicate entry.');
    final bool isSubcomponent = hasAnnotation(entry, const {'Subcomponent'});
    if (spec.wantsSubcomponents && !isSubcomponent) {
      return ("'${entry.name}' in $list is not annotated with '@subcomponent'.", addAnnotation);
    }
    if (!spec.wantsSubcomponents && isSubcomponent) {
      return (
        "'${entry.name}' in $list is a subcomponent, not a module.",
        "Install it with '@Module(subcomponents: [${entry.name}])' instead.",
      );
    }
    if (spec.field == 'includes' && !hasAnnotation(entry, const {'Module'})) {
      return ("'${entry.name}' in $list is not annotated with '@module'.", addAnnotation);
    }
    return null;
  }

  /// The list literal written for [spec] in [node], if any.
  ListLiteral? _literal(Annotation node, _ListSpec spec) {
    for (final Argument argument in node.arguments?.arguments ?? const <Argument>[]) {
      final Expression expression = argument.argumentExpression;
      final String field = argument is NamedArgument ? argument.name.lexeme : 'modules';
      if (field == spec.field && expression is ListLiteral) return expression;
    }
    return null;
  }
}
