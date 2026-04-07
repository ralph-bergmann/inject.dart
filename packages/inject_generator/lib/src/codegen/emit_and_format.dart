import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

/// Emits a [Library] spec and formats the result using [DartFormatter].
///
/// Generated files are prefixed with `// ignore_for_file: type=lint, type=warning`
/// so that project-level lint rules and analyzer warnings never break a user's build.
String emitAndFormat(Library librarySpec) {
  final emitter = DartEmitter.scoped(orderDirectives: true, useNullSafetySyntax: true);
  const header = '// ignore_for_file: type=lint, type=warning';
  final unformatted =
      '''
$header
${librarySpec.accept(emitter)}
''';
  return DartFormatter(languageVersion: DartFormatter.latestShortStyleLanguageVersion).format(unformatted);
}
