import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';

/// Resolves a Dart source fixture file into a [LibraryElement].
Future<LibraryElement> resolveFixture(String fixturePath) async {
  final String source = File(fixturePath).readAsStringSync();
  return resolveSource(
    source,
    (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
    readAllSourcesFromFilesystem: true,
  );
}

/// Emits a single [Class] spec as formatted Dart source.
String emitClass(Class classSpec) {
  final library = Library((b) => b..body.add(classSpec));
  final emitter = DartEmitter.scoped(orderDirectives: true, useNullSafetySyntax: true);
  return DartFormatter(
    languageVersion: DartFormatter.latestShortStyleLanguageVersion,
  ).format('${library.accept(emitter)}');
}

/// Compares [actual] output against a golden file at [goldenPath].
///
/// When the golden file does not exist or the `UPDATE_GOLDENS` environment
/// variable is set, the file is written with [actual] content. On first
/// creation (without `UPDATE_GOLDENS`), the test fails with instructions
/// to re-run.
void expectMatchesGolden(String actual, String goldenPath) {
  final file = File(goldenPath);
  final bool updateGoldens = Platform.environment.containsKey('UPDATE_GOLDENS');

  if (updateGoldens || !file.existsSync()) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    if (!updateGoldens) {
      fail('Golden file created at $goldenPath. Re-run to verify.');
    }
    return;
  }

  expect(actual, equals(file.readAsStringSync()));
}
