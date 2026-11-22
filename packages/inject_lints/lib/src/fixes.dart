import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import 'inject.dart';

/// Adds the `abstract` modifier to a class.
class AddAbstract extends ResolvedCorrectionProducer {
  static const _kind = FixKind('inject_lints.fix.addAbstract', DartFixKindPriority.standard, "Add 'abstract'");

  AddAbstract({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final ClassDeclaration? declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (declaration == null || declaration.abstractKeyword != null || declaration.sealedKeyword != null) return;
    final Token first = declaration.firstTokenAfterCommentAndMetadata;
    await builder.addDartFileEdit(file, (builder) => builder.addSimpleInsertion(first.offset, 'abstract '));
  }
}

/// Adds `@provides` to a module method.
class AddProvides extends ResolvedCorrectionProducer {
  static const _kind = FixKind('inject_lints.fix.addProvides', DartFixKindPriority.standard, "Add '@provides'");

  AddProvides({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final MethodDeclaration? method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;
    final int offset = method.firstTokenAfterCommentAndMetadata.offset;
    final String annotation = '@${_injectPrefix(unit)}provides';
    await builder.addDartFileEdit(
      file,
      (builder) => builder.addSimpleInsertion(offset, '$annotation${utils.endOfLine}${utils.getLinePrefix(offset)}'),
    );
  }
}

/// Removes the `@asynchronous` annotation that the diagnostic marks.
class RemoveAsynchronous extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'inject_lints.fix.removeAsynchronous',
    DartFixKindPriority.standard,
    "Remove '@asynchronous'",
  );

  RemoveAsynchronous({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final Annotation? annotation = node.thisOrAncestorOfType<Annotation>();
    if (annotation != null) await _deleteAnnotation(builder, file, annotation);
  }
}

/// Removes `@inject` or `@assistedInject` from a constructor.
class RemoveInjectAnnotation extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'inject_lints.fix.removeInjectAnnotation',
    DartFixKindPriority.standard,
    'Remove the inject annotation',
  );

  RemoveInjectAnnotation({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final ConstructorDeclaration? constructor = node.thisOrAncestorOfType<ConstructorDeclaration>();
    if (constructor == null) return;
    for (final Annotation annotation in constructor.metadata) {
      if (_isInjectAnnotation(annotation, const {'Inject', 'AssistedInject'})) {
        await _deleteAnnotation(builder, file, annotation);
      }
    }
  }
}

/// Replaces `@assistedInject` with `@inject` on a constructor.
class ReplaceWithInject extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'inject_lints.fix.replaceWithInject',
    DartFixKindPriority.standard,
    "Replace '@assistedInject' with '@inject'",
  );

  ReplaceWithInject({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.acrossSingleFile;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final ConstructorDeclaration? constructor = node.thisOrAncestorOfType<ConstructorDeclaration>();
    final Annotation? annotation = constructor?.metadata
        .where((a) => _isInjectAnnotation(a, const {'AssistedInject'}))
        .firstOrNull;
    if (annotation == null) return;
    final Identifier name = annotation.name;
    final SimpleIdentifier last = name is PrefixedIdentifier ? name.identifier : name as SimpleIdentifier;
    final String? replacement = switch (last.name) {
      'assistedInject' => 'inject',
      'AssistedInject' => 'Inject',
      _ => null,
    };
    if (replacement == null) return;
    await builder.addDartFileEdit(file, (builder) => builder.addSimpleReplacement(range.node(last), replacement));
  }
}

/// Removes a duplicate entry from a module or subcomponent list.
class RemoveDuplicateEntry extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'inject_lints.fix.removeDuplicateEntry',
    DartFixKindPriority.standard,
    'Remove the duplicate entry',
  );

  RemoveDuplicateEntry({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // The diagnostic covers the entry, but `node` can be a part of it.
    final AstNode? entry = node.thisOrAncestorMatching((n) => n.parent is ListLiteral);
    final AstNode? list = entry?.parent;
    if (entry is! Expression || list is! ListLiteral) return;
    final int index = list.elements.indexOf(entry);
    final bool isDuplicate = list.elements.take(index).any((e) => e is Expression && _typeOf(e) == _typeOf(entry));
    if (index < 1 || !isDuplicate) return;
    // Delete from the end of the previous entry, so its comma goes too.
    await builder.addDartFileEdit(
      file,
      (builder) => builder.addDeletion(range.endEnd(list.elements[index - 1], entry)),
    );
  }

  Object? _typeOf(Expression e) => switch (e) {
    TypeLiteral(:final type) => type.element,
    Identifier(:final element) => element,
    _ => e.toSource(),
  };
}

Future<void> _deleteAnnotation(ChangeBuilder builder, String file, Annotation annotation) => builder.addDartFileEdit(
  file,
  (builder) => builder.addDeletion(range.startStart(annotation, annotation.endToken.next!)),
);

bool _isInjectAnnotation(Annotation annotation, Set<String> classNames) {
  final type = annotation.elementAnnotation?.computeConstantValue()?.type?.element;
  return type != null && classNames.contains(type.name) && isFromPackage(type, 'inject_annotation');
}

/// The import prefix of `package:inject_annotation` with a trailing dot, or
/// an empty string.
String _injectPrefix(CompilationUnit unit) {
  for (final ImportDirective import in unit.directives.whereType<ImportDirective>()) {
    if (import.uri.stringValue?.startsWith('package:inject_annotation/') ?? false) {
      final String? prefix = import.prefix?.name;
      return prefix == null ? '' : '$prefix.';
    }
  }
  return '';
}
