import 'package:build/build.dart';
import 'package:inject_generator/src/source/symbol_path.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('parameter test', () {
    test('parameters', () async {
      const testFilePath = 'test/source/data/parameter.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final stb = SummaryTestBed(inputAssetId: testAssetId);
      await stb.run();
      stb.printLog();

      final summaries = stb.summaries;
      expect(summaries.length, 1);

      final summary = summaries.values.first;
      expect(summary, isNotNull);
      expect(summary.assetUri, testAssetId.uri);

      final injectables = summary.injectables;
      expect(injectables.length, 3);

      expect(
        injectables[0].clazz,
        const SymbolPath(rootPackage, testFilePath, 'Inject1'),
      );
      expect(injectables[0].constructor.dependencies.length, 3);
      expect(injectables[0].constructor.dependencies[0].name, 'foo');
      expect(injectables[0].constructor.dependencies[0].isRequired, true);
      expect(injectables[0].constructor.dependencies[0].isNamed, false);
      expect(injectables[0].constructor.dependencies[1].name, 'foo2');
      expect(injectables[0].constructor.dependencies[1].isRequired, false);
      expect(injectables[0].constructor.dependencies[1].isNamed, true);
      expect(injectables[0].constructor.dependencies[2].name, 'foo3');
      expect(injectables[0].constructor.dependencies[2].isRequired, true);
      expect(injectables[0].constructor.dependencies[2].isNamed, true);

      expect(
        injectables[1].clazz,
        const SymbolPath(rootPackage, testFilePath, 'Inject3'),
      );
      expect(injectables[1].constructor.dependencies.length, 2);
      expect(injectables[1].constructor.dependencies[0].name, 'factory');
      expect(injectables[1].constructor.dependencies[0].isRequired, true);
      expect(injectables[1].constructor.dependencies[1].name, 'factory2');
      expect(injectables[1].constructor.dependencies[1].isRequired, true);

      expect(
        injectables[2].clazz,
        const SymbolPath(rootPackage, testFilePath, 'Dependency1'),
      );

      final modules = summary.modules;
      expect(modules.length, 1);

      expect(
        modules[0].clazz,
        const SymbolPath(rootPackage, testFilePath, 'Inject2Module'),
      );

      expect(modules[0].providers.length, 1);
      final moduleProvider = modules[0].providers[0];

      expect(moduleProvider.dependencies.length, 3);
      expect(moduleProvider.dependencies[0].name, 'foo');
      expect(moduleProvider.dependencies[0].isRequired, true);
      expect(moduleProvider.dependencies[0].isNamed, false);
      expect(moduleProvider.dependencies[1].name, 'foo2');
      expect(moduleProvider.dependencies[1].isRequired, false);
      expect(moduleProvider.dependencies[1].isNamed, true);
      expect(moduleProvider.dependencies[2].name, 'foo3');
      expect(moduleProvider.dependencies[2].isRequired, true);
      expect(moduleProvider.dependencies[2].isNamed, true);

      final factories = summary.factories;
      expect(factories.length, 2);

      expect(
        factories[0].clazz,
        const SymbolPath(rootPackage, testFilePath, 'Inject4Factory'),
      );
      expect(
        factories[1].clazz,
        const SymbolPath(rootPackage, testFilePath, 'Inject5Factory'),
      );

      expect(
        factories[0].factory.createdType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Inject4'),
      );
      expect(factories[0].factory.createdType.isAssisted, true);
      expect(factories[0].factory.parameters.length, 1);
      expect(
        factories[0].factory.parameters[0].lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Dependency2'),
      );
      expect(factories[0].factory.parameters[0].name, 'foo');

      final asset = stb.components.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
    });
  });
}
