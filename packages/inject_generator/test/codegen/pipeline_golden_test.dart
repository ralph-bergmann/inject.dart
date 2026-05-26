import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/inject_generator.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../helpers/golden_helper.dart';
import '../helpers/inject_annotation_stub.dart';
import '../helpers/pipeline_golden_helper.dart';

const _goldenDir = 'test/golden/pipeline_golden';

void main() {
  group('Pipeline goldens', () {
    test('synthesized_factory_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'synthesized_factory_component',
        goldenDir: _goldenDir,
        expectFactory: true,
      );
    });

    test(
      'synthesized_multi_constructor_component golden',
      () async {
        await runPipelineGolden(
          fixtureName: 'synthesized_multi_constructor_component',
          goldenDir: _goldenDir,
          expectFactory: true,
        );
      },
    );

    test(
      'synthesized_multi_ctor_nullable_factory_dep golden',
      () async {
        await runPipelineGolden(
          fixtureName: 'synthesized_multi_ctor_nullable_factory_dep',
          goldenDir: _goldenDir,
          expectFactory: true,
        );
      },
    );

    test(
      'synthesized_multi_ctor_nullable_wrapped_factory_dep golden',
      () async {
        await runPipelineGolden(
          fixtureName: 'synthesized_multi_ctor_nullable_wrapped_factory_dep',
          goldenDir: _goldenDir,
          expectFactory: true,
        );
      },
    );

    // plain @inject nullable dep widening (Foo? → Foo)
    test('nullable_dep_widening golden', () async {
      await runPipelineGolden(
        fixtureName: 'nullable_dep_widening',
        goldenDir: _goldenDir,
      );
    });

    // Isolated: synthesized factory + nullable wrap on
    // another synthesized factory type, without multi-ctor / qualifier noise.
    test('synthesized_factory_nullable_wrap_dep golden', () async {
      await runPipelineGolden(
        fixtureName: 'synthesized_factory_nullable_wrap_dep',
        goldenDir: _goldenDir,
        expectFactory: true,
      );
    });

    test('nested_synthesized_factory_component golden', () async {
      await runPipelineGolden(
        fixtureName: 'nested_synthesized_factory_component',
        goldenDir: _goldenDir,
        expectFactory: true,
      );
    });

    // module with required positional ctor → factory emits `required`
    // parameter without `?? DbModule()` fallback.
    test('module_required_constructor golden', () async {
      await runPipelineGolden(
        fixtureName: 'module_required_constructor',
        goldenDir: _goldenDir,
      );
    });

    // mixed modules (some with, some without default
    // ctor) → correct required/optional split, deterministic parameter order.
    test('mixed_modules golden', () async {
      await runPipelineGolden(
        fixtureName: 'mixed_modules',
        goldenDir: _goldenDir,
      );
    });

    // Mirror-Pair A — @Component([AppModule, TestModule]).
    // TestModule wins: _String$Provider holds _testModule and calls _module.message().
    test('module_override golden', () async {
      await runPipelineGolden(
        fixtureName: 'module_override',
        goldenDir: _goldenDir,
      );
    });

    // Mirror-Pair B — @Component([TestModule, AppModule]).
    // AppModule wins: _String$Provider holds _appModule and calls _module.message().
    // Any alphabetical sort makes both mirror-pair goldens identical → this test fails.
    test('module_override_reversed golden', () async {
      await runPipelineGolden(
        fixtureName: 'module_override_reversed',
        goldenDir: _goldenDir,
      );
    });

    // Qualifiers disambiguate — different qualifiers do NOT override.
    // Both _url$prod$Provider and _url$test$Provider must exist.
    test('qualifier_no_override golden', () async {
      await runPipelineGolden(
        fixtureName: 'qualifier_no_override',
        goldenDir: _goldenDir,
      );
    });

    // Async override — @Component([AppModule, TestModule]).
    // TestModule wins: _Database$Provider holds _testModule and calls _module.provideDb().
    test('async_module_override golden', () async {
      await runPipelineGolden(
        fixtureName: 'async_module_override',
        goldenDir: _goldenDir,
      );
    });

    // Same-qualifier inter-module override: both modules provide @prod String.
    // TestModule wins — BindingKey(String, 'prod') matches → AppModule entry dropped.
    test('same_qualifier_override golden', () async {
      await runPipelineGolden(
        fixtureName: 'same_qualifier_override',
        goldenDir: _goldenDir,
      );
    });

    // removeWhere scoping: TestModule overrides String, AppModule's unique int survives.
    // Proves the override predicate only drops matching keys.
    test('override_keeps_unique_binding golden', () async {
      await runPipelineGolden(
        fixtureName: 'override_keeps_unique_binding',
        goldenDir: _goldenDir,
      );
    });

    // Sync + async override in the same component (F6 closure).
    // TestModule wins for both _String$Provider and _Database$Provider.
    test('sync_async_mixed_override golden', () async {
      await runPipelineGolden(
        fixtureName: 'sync_async_mixed_override',
        goldenDir: _goldenDir,
      );
    });

    // Determinism: run the mixed_modules pipeline twice and assert
    // byte-identical output.  Guards against non-deterministic Map iteration
    // order slipping through if sorting is removed.
    test('mixed_modules determinism: two runs produce identical output', () async {
      final String source = File('$_goldenDir/mixed_modules.dart').readAsStringSync();
      final String? run1 = await _runPipelineGetInjectOutput(source, 'mixed_modules');
      final String? run2 = await _runPipelineGetInjectOutput(source, 'mixed_modules');
      expect(run1, isNotNull, reason: 'First pipeline run produced no .inject.dart');
      expect(run2, isNotNull, reason: 'Second pipeline run produced no .inject.dart');
      expect(run1, equals(run2), reason: 'Two pipeline runs must produce byte-identical output');
    });

    // Error-path test: the EntryPointValidator (Phase 5) catches a
    // sync entry-point on an async dependency chain before codegen runs.
    //
    // Origin: this fixture was originally a TDD proof that the in-process
    // analyzer detects RETURN_OF_INVALID_TYPE in the (then-still-generated)
    // buggy `.inject.dart`. The generator was later fixed: the validator now
    // emits an error and suppresses output entirely, so there is nothing left
    // to analyse. The fixture input is unchanged; the `.inject.dart` golden
    // was deleted.
    test('async_chain_sync_entry_point_mismatch error path', () async {
      final String source = File('$_goldenDir/async_chain_sync_entry_point_mismatch.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions.empty);

      final logs = <LogRecord>[];

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/async_chain_sync_entry_point_mismatch.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
        onLog: logs.add,
      );

      // Validator suppresses output — no .inject.dart generated.
      expect(
        result.outputs.where((id) => id.path.endsWith('.inject.dart')),
        isEmpty,
        reason: 'Graph validation error must suppress .inject.dart output',
      );

      // The SEVERE log must contain the expected diagnostic text. Non-empty
      // check guards against build-setup failures that would otherwise let
      // the test pass vacuously with no logs emitted at all.
      final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
      expect(
        severeMessages,
        isNotEmpty,
        reason: 'Build produced no SEVERE logs — validator probably did not run',
      );
      expect(
        severeMessages,
        anyElement(
          contains("Component getter 'repository' is declared synchronous but its dependency chain is asynchronous."),
        ),
        reason: 'Expected validator diagnostic in build log',
      );
    });

    // Qualifier-aware nullable widening — unqualified
    // `Engine?` dep with only `@branded Engine` bound must produce qualifier-
    // mismatch diagnostic via second-pass `_findRelatedBindings(nonNullable)`.
    test('nullable_dep_qualifier_mismatch error path', () async {
      final String source = File('$_goldenDir/nullable_dep_qualifier_mismatch.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions.empty);

      final logs = <LogRecord>[];

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/nullable_dep_qualifier_mismatch.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
        onLog: logs.add,
      );

      expect(
        result.outputs.where((id) => id.path.endsWith('.inject.dart')),
        isEmpty,
        reason: 'Graph validation error must suppress .inject.dart output',
      );

      final List<String> severeMessages = logs
          .where((l) => l.level == Level.SEVERE)
          .map((l) => l.message)
          .toList();
      expect(
        severeMessages,
        isNotEmpty,
        reason: 'Build produced no SEVERE logs — validator probably did not run',
      );
      // Expect qualifier-mismatch diagnostic (Scenario 1), not generic "also tried".
      expect(
        severeMessages,
        anyElement(
          allOf(
            contains("No unqualified binding for 'Engine?'"),
            contains('#branded'),
          ),
        ),
        reason: 'Expected qualifier-mismatch diagnostic via nullable second-pass fallback',
      );
      // Negative: must NOT fall back to the generic "(also tried 'Engine')" message.
      expect(
        severeMessages.any((m) => m.contains('also tried')),
        isFalse,
        reason: 'When a qualified non-nullable binding exists, validator should emit '
            'qualifier-mismatch instead of "(also tried)" generic widening hint',
      );
    });

    // default policy (error) fires when both Foo and Foo?
    // are bound. Validator suppresses .inject.dart output.
    test('nullable_duplicate_binding_error error path', () async {
      final String source = File('$_goldenDir/nullable_duplicate_binding_error.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions.empty);

      final logs = <LogRecord>[];

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/nullable_duplicate_binding_error.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
        onLog: logs.add,
      );

      expect(
        result.outputs.where((id) => id.path.endsWith('.inject.dart')),
        isEmpty,
        reason: 'Nullable-duplicate error must suppress .inject.dart output',
      );

      final List<String> severeMessages =
          logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
      expect(
        severeMessages,
        isNotEmpty,
        reason: 'Build produced no SEVERE logs — validator probably did not run',
      );
      expect(
        severeMessages,
        anyElement(
          allOf(
            contains('Duplicate binding for type'),
            contains('nullable'),
            contains('non-nullable'),
            contains('nullable_duplicate_binding_policy: allow'),
          ),
        ),
        reason: 'Expected nullable-duplicate diagnostic with allow suggestion',
      );
    });

    // allow policy — both Foo and Foo? bindings survive,
    // both providers are generated, no error.
    test('nullable_duplicate_binding_allow golden', () async {
      await runPipelineGolden(
        fixtureName: 'nullable_duplicate_binding_allow',
        goldenDir: _goldenDir,
        injectBuilderOptions: BuilderOptions({'nullable_duplicate_binding_policy': 'allow'}),
      );
    });

    // warn policy — both bindings survive, WARNING emitted,
    // both providers are generated.
    test('nullable_duplicate_binding_warn golden + warning', () async {
      final String source = File('$_goldenDir/nullable_duplicate_binding_warn.dart').readAsStringSync();

      // Policy options belong to inject_builder only (factory_builder accepts
      // no options under the builder-options split — see FactoryBuilderOptions).
      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions({'nullable_duplicate_binding_policy': 'warn'}));

      final logs = <LogRecord>[];

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/nullable_duplicate_binding_warn.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
        onLog: logs.add,
      );

      expect(result.succeeded, isTrue, reason: 'warn policy must not fail the build');

      final AssetId injectOutputId = result.readerWriter.testing.assets.firstWhere(
        (id) => id.path.endsWith('.inject.dart'),
        orElse: () => throw StateError('No .inject.dart output for warn golden'),
      );
      final String injectOutput = result.readerWriter.testing.readString(injectOutputId);
      expectMatchesGolden(injectOutput, '$_goldenDir/nullable_duplicate_binding_warn.inject.dart');

      // WARNING-level log must contain the duplicate diagnostic.
      final List<String> warnMessages =
          logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
      expect(
        warnMessages,
        isNotEmpty,
        reason: 'Build produced no WARNING logs — warn policy probably did not run',
      );
      expect(
        warnMessages,
        anyElement(
          allOf(
            contains('Duplicate binding for type'),
            contains('nullable'),
            contains('non-nullable'),
          ),
        ),
        reason: 'Expected nullable-duplicate WARNING diagnostic for warn policy',
      );
    });

    // same module provides both qualified and unqualified binding
    // for the same base type — WARNING is emitted, codegen proceeds, both providers
    // are generated.
    test('qualified_unqualified_same_module golden + warning', () async {
      final String source = File('$_goldenDir/qualified_unqualified_same_module.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions.empty);

      final logs = <LogRecord>[];

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/qualified_unqualified_same_module.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
        onLog: logs.add,
      );

      expect(result.succeeded, isTrue, reason: 'Qualified/unqualified warning must not fail the build');

      final AssetId injectOutputId = result.readerWriter.testing.assets.firstWhere(
        (id) => id.path.endsWith('.inject.dart'),
        orElse: () => throw StateError('No .inject.dart output — warning must not suppress codegen'),
      );
      final String injectOutput = result.readerWriter.testing.readString(injectOutputId);
      expectMatchesGolden(injectOutput, '$_goldenDir/qualified_unqualified_same_module.inject.dart');

      // WARNING-level log must contain the qualified/unqualified diagnostic.
      final List<String> warnMessages =
          logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
      expect(
        warnMessages,
        isNotEmpty,
        reason: 'Build produced no WARNING logs — conflict check probably did not run',
      );
      expect(
        warnMessages,
        anyElement(
          allOf(
            contains('qualified'),
            contains('unqualified'),
          ),
        ),
        reason: 'Expected qualified/unqualified conflict WARNING diagnostic',
      );
    });

    // debug_graph: true — tree appears in stdout, codegen unchanged.
    test('debug_graph on-path golden + print assertion', () async {
      final String source = File('$_goldenDir/debug_graph.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);

      final printed = <String>[];
      final Builder inject = LibraryBuilder(
        InjectBuilder(
          options: InjectBuilderOptions.fromBuilderOptions(BuilderOptions({'debug_graph': true})),
          debugPrint: printed.add,
        ),
        generatedExtension: '.inject.dart',
      );

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/debug_graph.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
      );

      expect(result.succeeded, isTrue, reason: 'debug_graph must not fail the build');

      final AssetId injectOutputId = result.readerWriter.testing.assets.firstWhere(
        (id) => id.path.endsWith('.inject.dart'),
        orElse: () => throw StateError('No .inject.dart output for debug_graph golden'),
      );
      final String injectOutput = result.readerWriter.testing.readString(injectOutputId);

      // Codegen must be unchanged (golden equality check).
      expectMatchesGolden(injectOutput, '$_goldenDir/debug_graph.inject.dart');

      // print() output must contain the tree.
      final String allPrinted = printed.join('\n');

      expect(allPrinted, contains('[inject_generator] Dependency graph for CoffeeShop:'),
          reason: 'Tree header must be present in printed output');
      expect(allPrinted, contains('Heater...'), reason: 'Shared node reference must appear in main tree');
      expect(allPrinted, contains('shared bindings'), reason: 'Shared-block sub-header must appear');
      expect(allPrinted, contains('injected by: Brewer, Grinder'), reason: 'Receiver annotation must appear in shared block');
      expect(allPrinted, contains('@singleton'), reason: 'Singleton annotation must appear');
      expect(allPrinted, contains('@async'), reason: 'Async annotation must appear');
    });

    // off-path regression — no debug_graph option means no print output.
    test('debug_graph off-path — no tree printed', () async {
      final String source = File('$_goldenDir/debug_graph.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);

      final printed = <String>[];
      final Builder inject = LibraryBuilder(
        InjectBuilder(debugPrint: printed.add),
        generatedExtension: '.inject.dart',
      );

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/debug_graph.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
      );

      expect(result.succeeded, isTrue);
      expect(printed.join('\n'), isNot(contains('Dependency graph for')),
          reason: 'No tree output when debug_graph is not set');
    });

    // Multi-component debug_graph: two @components in one library produce two
    // trees in declaration order with a blank-line separator. Verifies that
    // GraphValidator's `_last*` snapshots survive the per-component loop.
    test('debug_graph multi-component — one tree per component, blank-line separated', () async {
      await runPipelineGolden(
        fixtureName: 'debug_graph_multi',
        goldenDir: _goldenDir,
      );

      final String source = File('$_goldenDir/debug_graph_multi.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);

      final printed = <String>[];
      final Builder inject = LibraryBuilder(
        InjectBuilder(
          options: InjectBuilderOptions.fromBuilderOptions(BuilderOptions({'debug_graph': true})),
          debugPrint: printed.add,
        ),
        generatedExtension: '.inject.dart',
      );

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/debug_graph_multi.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
      );

      expect(result.succeeded, isTrue, reason: 'multi-component debug_graph must not fail the build');

      final String allPrinted = printed.join('\n');

      // Both component trees must be present, each with its own header.
      expect(allPrinted, contains('[inject_generator] Dependency graph for CoffeeShop:'),
          reason: 'CoffeeShop tree header must be printed');
      expect(allPrinted, contains('[inject_generator] Dependency graph for TeaShop:'),
          reason: 'TeaShop tree header must be printed');

      // Each component's body must appear under the correct header. Verify
      // by checking that the entry-point appears AFTER its component's header
      // and BEFORE the other component's header (snapshot isolation: each
      // component's tree must contain only its own graph).
      final coffeeHeaderIdx = allPrinted.indexOf('Dependency graph for CoffeeShop:');
      final teaHeaderIdx = allPrinted.indexOf('Dependency graph for TeaShop:');
      expect(coffeeHeaderIdx, greaterThanOrEqualTo(0));
      expect(teaHeaderIdx, greaterThan(coffeeHeaderIdx));

      // CoffeeShop's tree contains Brewer and Heater (@singleton) — both
      // before the TeaShop header.
      final coffeeBody = allPrinted.substring(coffeeHeaderIdx, teaHeaderIdx);
      expect(coffeeBody, contains('Brewer'), reason: 'CoffeeShop body must contain its entry-point');
      expect(coffeeBody, contains('Heater (@singleton)'),
          reason: 'CoffeeShop body must contain its Heater binding with singleton annotation');
      expect(coffeeBody, isNot(contains('Steeper')),
          reason: 'CoffeeShop body must NOT leak TeaShop bindings (snapshot isolation)');
      expect(coffeeBody, isNot(contains('Kettle')),
          reason: 'CoffeeShop body must NOT leak TeaShop bindings (snapshot isolation)');

      // TeaShop's tree contains Steeper and Kettle — and no CoffeeShop deps.
      final teaBody = allPrinted.substring(teaHeaderIdx);
      expect(teaBody, contains('Steeper'), reason: 'TeaShop body must contain its entry-point');
      expect(teaBody, contains('Kettle'), reason: 'TeaShop body must contain its Kettle binding');
      expect(teaBody, isNot(contains('Brewer')),
          reason: 'TeaShop body must NOT leak CoffeeShop bindings (snapshot isolation)');
      expect(teaBody, isNot(contains('Heater')),
          reason: 'TeaShop body must NOT leak CoffeeShop bindings (snapshot isolation)');

      // Trees must be separated by a blank-string print() call (visual gap).
      final coffeePrintIdx = printed.indexWhere((line) => line.contains('Dependency graph for CoffeeShop:'));
      final teaPrintIdx = printed.indexWhere((line) => line.contains('Dependency graph for TeaShop:'));
      final between = printed.sublist(coffeePrintIdx + 1, teaPrintIdx);
      expect(between, contains(''),
          reason: 'Blank-line entry must separate the two component trees in the print buffer');
    });

    // loud failure with "also tried" when neither Foo? nor Foo is bound
    test('nullable_dep_no_binding error path', () async {
      final String source = File('$_goldenDir/nullable_dep_no_binding.dart').readAsStringSync();

      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions.empty);

      final logs = <LogRecord>[];

      final TestBuilderResult result = await testBuilders(
        [factory, inject],
        {
          ...injectAnnotationAssets,
          'pkg|lib/nullable_dep_no_binding.dart': source,
        },
        rootPackage: 'pkg',
        visibleOutputBuilders: {factory},
        appliesBuilders: {
          factory: ['inject_generator|inject_builder'],
        },
        flattenOutput: true,
        onLog: logs.add,
      );

      expect(
        result.outputs.where((id) => id.path.endsWith('.inject.dart')),
        isEmpty,
        reason: 'Graph validation error must suppress .inject.dart output',
      );

      final List<String> severeMessages = logs
          .where((l) => l.level == Level.SEVERE)
          .map((l) => l.message)
          .toList();
      expect(
        severeMessages,
        isNotEmpty,
        reason: 'Build produced no SEVERE logs — validator probably did not run',
      );
      // Diagnostic must mention the nullable type and the fallback that was tried
      expect(
        severeMessages,
        anyElement(allOf(contains("Missing?"), contains('also tried'), contains("'Missing'"))),
        reason: "Expected 'also tried' diagnostic for nullable dep with no binding",
      );
    });
  });
}

/// Runs the factory → inject pipeline on [source] and returns the generated
/// `.inject.dart` content, or `null` when the build produced no output.
Future<String?> _runPipelineGetInjectOutput(String source, String fixtureName) async {
  final Builder factory = factoryBuilder(BuilderOptions.empty);
  final Builder inject = injectBuilder(BuilderOptions.empty);

  final TestBuilderResult result = await testBuilders(
    [factory, inject],
    {
      ...injectAnnotationAssets,
      'pkg|lib/$fixtureName.dart': source,
    },
    rootPackage: 'pkg',
    visibleOutputBuilders: {factory},
    appliesBuilders: {
      factory: ['inject_generator|inject_builder'],
    },
    flattenOutput: true,
  );

  final AssetId? injectOutputId = result.readerWriter.testing.assets
      .where((id) => id.path.endsWith('.inject.dart'))
      .firstOrNull;
  if (injectOutputId == null) {
    return null;
  }
  return result.readerWriter.testing.readString(injectOutputId);
}
