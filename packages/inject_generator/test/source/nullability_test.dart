import 'package:build/build.dart';
import 'package:inject_generator/src/source/symbol_path.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('nullability test', () {
    test('nullability all good', () async {
      const testFilePath = 'test/source/data/nullability.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final stb = SummaryTestBed(inputAssetId: testAssetId);
      await stb.run();
      stb.printLog();

      final summaries = stb.summaries;
      expect(summaries.length, 1);

      final summary = summaries.values.first;
      expect(summary, isNotNull);
      expect(summary.assetUri, testAssetId.uri);

      final components = stb.components.values.first.components;
      expect(components.length, 1);
      expect(
        components[0].clazz,
        const SymbolPath(rootPackage, testFilePath, 'ComponentNullability'),
      );

      expect(components[0].providers.length, 3);

      expect(components[0].providers[0].name, 'fooBar');
      expect(
        components[0].providers[0].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'FooBar'),
      );
      expect(
        components[0].providers[0].injectedType.isNullable,
        false,
      );

      expect(components[0].providers[1].name, 'foo');
      expect(
        components[0].providers[1].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Foo'),
      );
      expect(
        components[0].providers[1].injectedType.isNullable,
        false,
      );

      expect(components[0].providers[2].name, 'bar');
      expect(
        components[0].providers[2].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );
      expect(
        components[0].providers[2].injectedType.isNullable,
        true,
      );

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
    });

    test('nullability error in component', () async {
      const testFilePath = 'test/source/data/nullability_error_component.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final stb = SummaryTestBed(inputAssetId: testAssetId);
      await stb.run();
      stb.printLog();

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
      ctb
        ..printLog()
        ..expectLogRecord(
          Level.SEVERE,
          'Could not find a way to provide "Bar" which is injected in "ComponentNullability".',
        );
    });

    test('nullability error in module', () async {
      const testFilePath = 'test/source/data/nullability_error_module.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final stb = SummaryTestBed(inputAssetId: testAssetId);
      await stb.run();
      stb.printLog();

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
      ctb
        ..printLog()
        ..expectLogRecord(
          Level.SEVERE,
          'Could not find a way to provide "Bar" which is injected in "BarModule".',
        );
    });
  });
}
