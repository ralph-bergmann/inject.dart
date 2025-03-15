import 'package:build/build.dart';
import 'package:inject_generator/src/source/symbol_path.dart';
import 'package:test/test.dart';

import '../utils.dart';

void main() {
  group('annotations test', () {
    test('component without module', () async {
      const testFilePath = 'test/source/data/component_without_module.dart';
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
      final component = components[0];

      expect(
        component.clazz,
        const SymbolPath(rootPackage, testFilePath, 'ComponentWithoutModule'),
      );
      expect(component.providers.length, 1);
      expect(component.providers[0].name, 'getBar');
      expect(
        component.providers[0].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );

      expect(summary.injectables.length, 1);
      expect(
        summary.injectables[0].clazz,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
    });

    test('component with module', () async {
      const testFilePath = 'test/source/data/component_with_module.dart';
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
      final component = components[0];

      expect(
        component.clazz,
        const SymbolPath(rootPackage, testFilePath, 'ComponentWithModule'),
      );
      expect(component.providers.length, 1);
      expect(component.providers[0].name, 'bar');
      expect(
        component.providers[0].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );

      expect(summary.injectables.length, 0);

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
    });

    test('component with @provides', () async {
      const testFilePath = 'test/source/data/component_with_provides.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final tb = SummaryTestBed(inputAssetId: testAssetId);
      expect(
        () async => tb.run(),
        throwsA(
          predicate(
            (e) =>
                e is StateError &&
                e.message.contains(
                  '@provides annotation is not supported for components',
                ),
          ),
        ),
      );
      tb.printLog();
    });

    test('module with @inject', () async {
      const testFilePath = 'test/source/data/module_with_inject.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final tb = SummaryTestBed(inputAssetId: testAssetId);
      expect(
        () async => tb.run(),
        throwsA(
          predicate(
            (e) =>
                e is StateError &&
                e.message.contains(
                  '@inject annotation is not supported for modules',
                ),
          ),
        ),
      );
      tb.printLog();
    });

    test('module', () async {
      const testFilePath = 'test/source/data/module.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final stb = SummaryTestBed(inputAssetId: testAssetId);
      await stb.run();
      stb.printLog();

      final summaries = stb.summaries;
      expect(summaries.length, 1);

      final summary = summaries.values.first;
      expect(summary, isNotNull);
      expect(summary.assetUri, testAssetId.uri);
      expect(summary.modules.length, 1);

      final module = summary.modules[0];
      expect(
        module.clazz,
        const SymbolPath(rootPackage, testFilePath, 'MainModule'),
      );

      expect(module.providers.length, 3);

      expect(module.providers[0].name, 'provideAddition');
      expect(
        module.providers[0].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Addition'),
      );

      expect(module.providers[1].name, 'provideFoo');
      expect(
        module.providers[1].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Foo'),
      );
      expect(module.providers[1].injectedType.isSingleton, true);

      expect(module.providers[2].name, 'provideBar');
      expect(
        module.providers[2].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );
      expect(module.providers[2].injectedType.isAsynchronous, true);

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
    });

    test('singleton inject', () async {
      const testFilePath = 'test/source/data/singleton_inject.dart';
      final testAssetId = AssetId(rootPackage, testFilePath);
      final stb = SummaryTestBed(inputAssetId: testAssetId);
      await stb.run();
      stb.printLog();

      final summaries = stb.summaries;
      expect(summaries.length, 1);

      final summary = summaries.values.first;
      expect(summary, isNotNull);
      expect(summary.assetUri, testAssetId.uri);
      expect(summary.modules.length, 1);

      final module = summary.modules[0];
      expect(
        module.clazz,
        const SymbolPath(rootPackage, testFilePath, 'BarModule'),
      );
      expect(module.providers.length, 1);
      expect(module.providers[0].name, 'bar');
      expect(
        module.providers[0].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );
      expect(module.providers[0].injectedType.isSingleton, true);

      expect(summary.injectables.length, 2);
      final injectable0 = summary.injectables[0];
      final injectable1 = summary.injectables[1];

      expect(
        injectable0.clazz,
        const SymbolPath(rootPackage, testFilePath, 'Foo'),
      );
      expect(injectable0.constructor.injectedType.isSingleton, true);

      expect(
        injectable1.clazz,
        const SymbolPath(rootPackage, testFilePath, 'Foo2'),
      );
      expect(injectable1.constructor.injectedType.isSingleton, true);

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
    });

    test('assisted inject', () async {
      const testFilePath = 'test/source/data/assisted_inject.dart';
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

      final component = components[0];
      expect(
        component.clazz,
        const SymbolPath(rootPackage, testFilePath, 'Component'),
      );
      expect(component.providers.length, 2);
      expect(component.providers[0].name, 'annotatedClassFactory');
      expect(
        component.providers[0].injectedType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'AnnotatedClassFactory'),
      );
      expect(component.providers[1].name, 'annotatedConstructorFactory');
      expect(
        component.providers[1].injectedType.lookupKey.root,
        const SymbolPath(
          rootPackage,
          testFilePath,
          'AnnotatedConstructorFactory',
        ),
      );

      expect(summary.injectables.length, 1);
      final foo = summary.injectables[0];
      expect(foo.clazz, const SymbolPath(rootPackage, testFilePath, 'Foo'));

      expect(summary.factories.length, 2);
      final annotatedClassFactory = summary.factories[0];
      final annotatedConstructorFactory = summary.factories[1];

      expect(
        annotatedClassFactory.clazz,
        const SymbolPath(rootPackage, testFilePath, 'AnnotatedClassFactory'),
      );
      expect(
        annotatedClassFactory.factory.createdType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'AnnotatedClass'),
      );

      expect(
        annotatedConstructorFactory.clazz,
        const SymbolPath(
          rootPackage,
          testFilePath,
          'AnnotatedConstructorFactory',
        ),
      );
      expect(
        annotatedConstructorFactory.factory.createdType.lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'AnnotatedConstructor'),
      );

      expect(summary.assistedInjectables.length, 2);
      final annotatedClass = summary.assistedInjectables[0];
      final annotatedConstructor = summary.assistedInjectables[1];

      expect(
        annotatedClass.clazz,
        const SymbolPath(rootPackage, testFilePath, 'AnnotatedClass'),
      );
      expect(annotatedClass.constructor.injectedType.isAssisted, true);
      expect(annotatedClass.constructor.dependencies.length, 2);
      expect(
        annotatedClass.constructor.dependencies[0].lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Foo'),
      );
      expect(annotatedClass.constructor.dependencies[0].isAssisted, false);
      expect(
        annotatedClass.constructor.dependencies[1].lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );
      expect(annotatedClass.constructor.dependencies[1].isAssisted, true);

      expect(
        annotatedConstructor.clazz,
        const SymbolPath(rootPackage, testFilePath, 'AnnotatedConstructor'),
      );
      expect(annotatedConstructor.constructor.injectedType.isAssisted, true);
      expect(annotatedConstructor.constructor.dependencies.length, 2);
      expect(
        annotatedConstructor.constructor.dependencies[0].lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Foo'),
      );
      expect(
        annotatedConstructor.constructor.dependencies[0].isAssisted,
        false,
      );
      expect(
        annotatedConstructor.constructor.dependencies[1].lookupKey.root,
        const SymbolPath(rootPackage, testFilePath, 'Bar'),
      );
      expect(annotatedConstructor.constructor.dependencies[1].isAssisted, true);

      final asset = stb.content.entries.first;
      final ctb = CodegenTestBed(inputAssetId: asset.key, sourceAssets: stb.assets);
      await ctb.run();
      await ctb.compare();
    });
  });
}
