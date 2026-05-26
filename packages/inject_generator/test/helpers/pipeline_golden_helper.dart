import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/inject_generator.dart';
import 'package:test/test.dart';

import 'analyzer_check_helper.dart';
import 'golden_helper.dart';
import 'inject_annotation_stub.dart';

/// Runs `factory_builder` → `inject_builder` in a single `testBuilders` call
/// and compares outputs against golden files.
///
/// Uses `appliesBuilders` so that `factory` runs before `inject`, mirroring
/// the `runs_before` relationship declared in `build.yaml`.
/// Uses `visibleOutputBuilders` so the factory output is written next to the
/// source (like `build_to: source`) instead of hidden under `.dart_tool`.
///
/// [fixtureName] is the base name without extension (e.g., 'minimal_component').
/// [goldenDir] is the directory containing the fixture and expected golden files.
/// [expectFactory] whether to expect and verify `.factory.dart` output.
/// [expectInject] whether to expect and verify `.inject.dart` output.
/// [runAnalyzer] when true (default), runs the Dart analyzer on the generated
/// `.inject.dart` after the equality check and fails if any ERROR-level
/// diagnostics are found. Set to `false` for fixtures that intentionally
/// produce type-invalid output (e.g. TDD proof tests that call
/// [expectAnalyzerErrors] directly).
Future<void> runPipelineGolden({
  required String fixtureName,
  required String goldenDir,
  bool expectFactory = false,
  bool expectInject = true,
  bool runAnalyzer = true,
  BuilderOptions injectBuilderOptions = BuilderOptions.empty,
  BuilderOptions factoryBuilderOptions = BuilderOptions.empty,
}) async {
  final String source = File('$goldenDir/$fixtureName.dart').readAsStringSync();

  final Builder factory = factoryBuilder(factoryBuilderOptions);
  final Builder inject = injectBuilder(injectBuilderOptions);

  final TestBuilderResult result = await testBuilders(
    [factory, inject],
    {
      ...injectAnnotationAssets,
      'pkg|lib/$fixtureName.dart': source,
    },
    rootPackage: 'pkg',
    // factory output visible to inject (= build_to: source)
    visibleOutputBuilders: {factory},
    // factory runs before inject (= runs_before in build.yaml)
    appliesBuilders: {
      factory: ['inject_generator|inject_builder'],
    },
    flattenOutput: true,
  );

  expect(result.succeeded, isTrue, reason: 'Pipeline build must succeed');

  String? factoryOutput;
  if (expectFactory) {
    final AssetId factoryOutputId = result.readerWriter.testing.assets.firstWhere(
      (id) => id.path.endsWith('.factory.dart'),
      orElse: () => throw StateError(
        'No .factory.dart output. Assets: '
        '${result.readerWriter.testing.assets}',
      ),
    );
    factoryOutput = result.readerWriter.testing.readString(factoryOutputId);
    expectMatchesGolden(
      factoryOutput,
      '$goldenDir/$fixtureName.factory.dart',
    );
  }

  String? injectOutput;
  if (expectInject) {
    final AssetId injectOutputId = result.readerWriter.testing.assets.firstWhere(
      (id) => id.path.endsWith('.inject.dart'),
      orElse: () => throw StateError(
        'No .inject.dart output. Assets: '
        '${result.readerWriter.testing.assets}',
      ),
    );
    injectOutput = result.readerWriter.testing.readString(injectOutputId);
    // Equality check first — a diff is more actionable than an analyzer failure.
    expectMatchesGolden(
      injectOutput,
      '$goldenDir/$fixtureName.inject.dart',
    );
  }

  // Analyzer pass: verify each emitted file is type-correct Dart.
  // Only ERROR-level diagnostics fail the test; warnings and hints are ignored.
  if (runAnalyzer) {
    if (injectOutput != null) {
      final additionalSources = <String, String>{'$fixtureName.dart': source};
      if (factoryOutput != null) {
        additionalSources['$fixtureName.factory.dart'] = factoryOutput;
      }
      await expectNoAnalyzerErrors(
        injectOutput,
        fileName: '$fixtureName.inject.dart',
        additionalSources: additionalSources,
      );
    }
    if (factoryOutput != null) {
      // `.factory.dart` is a part file (`part of '<fixture>.dart'`); the
      // host fixture in additionalSources contains the matching `part`
      // directive, so the analyzer can resolve the relationship.
      final additionalSources = <String, String>{'$fixtureName.dart': source};
      if (injectOutput != null) {
        additionalSources['$fixtureName.inject.dart'] = injectOutput;
      }
      await expectNoAnalyzerErrors(
        factoryOutput,
        fileName: '$fixtureName.factory.dart',
        additionalSources: additionalSources,
      );
    }
  }
}
