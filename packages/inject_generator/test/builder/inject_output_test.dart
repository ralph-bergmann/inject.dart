import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/inject_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../helpers/inject_annotation_stub.dart';

const _imports = "import 'package:inject_annotation/inject_annotation.dart';";

const _componentSource =
    '''
$_imports

class Foo {
  @inject
  Foo();
}

@component
abstract class CoffeeShop {
  Foo get foo;
}
''';

const _componentConstructorSource =
    '''
$_imports

class Foo {
  @inject
  Foo();
}

@Component()
abstract class CoffeeShop {
  Foo get foo;
}
''';

const _plainClassSource = '''
class Foo {}
''';

const _injectOnlySource =
    '''
$_imports

@inject
class MyService {}
''';

const _emptyLibrarySource = '''
// intentionally empty
''';

const _mixedSource =
    '''
$_imports

class Foo {
  @inject
  Foo();
}

@component
abstract class CoffeeShop {
  Foo get foo;
}

class PlainHelper {}
''';

const _multiComponentSource =
    '''
$_imports

class Foo {
  @inject
  Foo();
}

@component
abstract class BetaShop {
  Foo get foo;
}

@component
abstract class AlphaShop {
  Foo get foo;
}
''';

const _componentWithAssistedFactorySource =
    '''
$_imports

part 'coffee_shop.factory.dart';

class Grinder {
  @inject
  Grinder();
}

class Latte {
  @assistedInject
  Latte(Grinder grinder, {@assisted required String name});
}

@component
abstract class CoffeeShop {
  LatteFactory get latteFactory;
}
''';

const _componentWithFactoryEntryPointSource =
    '''
$_imports

class Grinder {
  @inject
  Grinder();
}

class Latte {
  @assistedInject
  Latte(Grinder grinder, {@assisted required String name});
}

@assistedFactory
abstract class LatteFactory {
  Latte create({required String name});
}

@component
abstract class CoffeeShop {
  @inject
  LatteFactory get latteFactory;
}
''';

void main() {
  group('InjectBuilder output', () {
    late Builder builder;

    setUp(() {
      builder = LibraryBuilder(InjectBuilder(), generatedExtension: '.inject.dart');
    });

    group('component detection', () {
      test('produces .inject.dart for @component-annotated class', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {...injectAnnotationAssets, 'pkg|lib/coffee_shop.dart': _componentSource},
          outputs: {'pkg|lib/coffee_shop.inject.dart': anything},
        );

        expect(result.succeeded, isTrue);
      });

      test('produces .inject.dart for @Component()-annotated class', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {...injectAnnotationAssets, 'pkg|lib/coffee_shop.dart': _componentConstructorSource},
          outputs: {'pkg|lib/coffee_shop.inject.dart': anything},
        );

        expect(result.succeeded, isTrue);
      });

      test('produces no output for plain class without annotations', () async {
        final TestBuilderResult result = await testBuilder(builder, {'pkg|lib/foo.dart': _plainClassSource});

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
      });

      test('produces no output for @inject without @component', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/service.dart': _injectOnlySource,
        });

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
      });

      test('produces no output for empty library', () async {
        final TestBuilderResult result = await testBuilder(builder, {'pkg|lib/empty.dart': _emptyLibrarySource});

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
      });

      test('generates only for @component class, ignores plain class', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {...injectAnnotationAssets, 'pkg|lib/mixed.dart': _mixedSource},
          outputs: {'pkg|lib/mixed.inject.dart': anything},
          flattenOutput: true,
        );

        final String output = result.readerWriter.testing.readString(AssetId('pkg', 'lib/mixed.inject.dart'));
        expect(output, contains(r'CoffeeShop$Component'));
        expect(output, isNot(contains('PlainHelper')));
      });
    });

    group('generated output content', () {
      test('generates stub class implementing the component', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {...injectAnnotationAssets, 'pkg|lib/coffee_shop.dart': _componentSource},
          outputs: {'pkg|lib/coffee_shop.inject.dart': anything},
          flattenOutput: true,
        );

        final String output = result.readerWriter.testing.readString(AssetId('pkg', 'lib/coffee_shop.inject.dart'));
        expect(output, contains(r'class CoffeeShop$Component'));
        expect(output, contains('implements'));
      });

      test('generated output uses scoped import aliases', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {...injectAnnotationAssets, 'pkg|lib/coffee_shop.dart': _componentSource},
          outputs: {'pkg|lib/coffee_shop.inject.dart': anything},
          flattenOutput: true,
        );

        final String output = result.readerWriter.testing.readString(AssetId('pkg', 'lib/coffee_shop.inject.dart'));
        // DartEmitter.scoped produces _i1, _i2, etc. alias prefixes.
        expect(output, contains('_i'));
      });

      test('generates component classes for all @component in file', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {...injectAnnotationAssets, 'pkg|lib/shops.dart': _multiComponentSource},
          outputs: {'pkg|lib/shops.inject.dart': anything},
          flattenOutput: true,
        );

        final String output = result.readerWriter.testing.readString(AssetId('pkg', 'lib/shops.inject.dart'));
        // CodeGenerator processes all components in a library.
        expect(output, contains(r'AlphaShop$Component'));
        expect(output, contains(r'BetaShop$Component'));
      });
    });

    group('determinism', () {
      test('produces byte-identical output across repeated builds', () async {
        final Map<String, String> sources = {...injectAnnotationAssets, 'pkg|lib/coffee_shop.dart': _componentSource};

        final TestBuilderResult result1 = await testBuilder(
          builder,
          sources,
          outputs: {'pkg|lib/coffee_shop.inject.dart': anything},
          flattenOutput: true,
        );

        // Rebuild with a fresh builder to ensure no state leaks.
        final freshBuilder = LibraryBuilder(InjectBuilder(), generatedExtension: '.inject.dart');

        final TestBuilderResult result2 = await testBuilder(
          freshBuilder,
          sources,
          outputs: {'pkg|lib/coffee_shop.inject.dart': anything},
          flattenOutput: true,
        );

        final String output1 = result1.readerWriter.testing.readString(AssetId('pkg', 'lib/coffee_shop.inject.dart'));
        final String output2 = result2.readerWriter.testing.readString(AssetId('pkg', 'lib/coffee_shop.inject.dart'));
        expect(output1, equals(output2));
      });
    });

    group('builder ordering compatibility', () {
      test('factory builder runs before inject builder in the full pipeline', () async {
        final Builder factoryBld = factoryBuilder(BuilderOptions.empty);
        final Builder injectBld = injectBuilder(BuilderOptions.empty);

        final TestBuilderResult result = await testBuilders(
          [factoryBld, injectBld],
          {
            ...injectAnnotationAssets,
            'pkg|lib/coffee_shop.dart': _componentWithAssistedFactorySource,
          },
          rootPackage: 'pkg',
          visibleOutputBuilders: {factoryBld},
          appliesBuilders: {factoryBld: ['inject_generator|inject_builder']},
          flattenOutput: true,
        );

        expect(result.succeeded, isTrue);
        expect(result.outputs.where((id) => id.path.endsWith('.factory.dart')), isNotEmpty);
        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isNotEmpty);
      });
    });

    group('assisted factory integration', () {
      test('generated output contains factory provider for @assistedFactory entry point', () async {
        final TestBuilderResult result = await testBuilder(
          builder,
          {...injectAnnotationAssets, 'pkg|lib/coffee_shop.dart': _componentWithFactoryEntryPointSource},
          outputs: {'pkg|lib/coffee_shop.inject.dart': anything},
          flattenOutput: true,
        );

        final String output = result.readerWriter.testing.readString(AssetId('pkg', 'lib/coffee_shop.inject.dart'));
        expect(output, contains(r'_LatteFactory$Provider'));
        expect(output, contains(r'_Grinder$Provider'));
        expect(output, contains(r'_LatteFactory$Factory'));
      });
    });
  });
}
