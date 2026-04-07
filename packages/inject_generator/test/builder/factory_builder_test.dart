import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/inject_generator.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../helpers/inject_annotation_stub.dart';
import '../helpers/pipeline_golden_helper.dart';

const _goldenDir = 'test/golden/factory_builder';

void main() {
  group('factoryBuilder', () {
    late Builder builder;

    setUp(() {
      builder = factoryBuilder(BuilderOptions.empty);
    });

    test('returns a PartBuilder', () {
      expect(builder, isA<PartBuilder>());
    });

    test('produces no .factory.dart output for unannotated source', () async {
      final TestBuilderResult result = await testBuilder(builder, {
        'pkg|lib/example.dart': '''
            part 'example.factory.dart';
            class Foo {}
          ''',
      });

      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'factoryBuilder must not produce output for unannotated code',
      );
      expect(result.succeeded, isTrue);
    });

    test('produces no output for @component source', () async {
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/example.dart': '''
            import 'package:inject_annotation/inject_annotation.dart';

            part 'example.factory.dart';

            class _PrivateService {}

            @component
            abstract class CoffeeShop {
              @inject
              _PrivateService get service;
            }
          ''',
      });

      expect(result.succeeded, isTrue);
      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'factoryBuilder produces no output without @assistedInject',
      );
    });

    test('reports error for @assistedInject without part directive', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              class MyService {
                @assistedInject
                const MyService({@assisted required this.name});
                final String name;
              }
            ''',
      }, onLog: logs.add);

      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'No output when part directive is missing',
      );
      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('missing the required part directive')),
      );
    });

    test('reports error for @assistedInject with mismatched part directive', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'other.factory.dart';

              class MyService {
                @assistedInject
                const MyService({@assisted required this.name});
                final String name;
              }
            ''',
      }, onLog: logs.add);

      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'No output when part directive does not match source file name',
      );
      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('missing the required part directive')),
      );
    });

    test('produces no error and no output for explicit @assistedFactory without part directive', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @assistedFactory
              abstract class MyServiceFactory {
                MyService create(String name);
              }

              class MyService {
                @assistedInject
                MyService(@assisted this.name, CoffeeService coffee);
                final String name;
              }

              class CoffeeService {}
            ''',
      }, onLog: logs.add);

      expect(result.succeeded, isTrue);
      expect(
        logs.where((l) => l.level == Level.SEVERE),
        isEmpty,
        reason: 'Explicit @assistedFactory should not require part directive',
      );
      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'No .factory.dart output needed for explicit-only factories',
      );
    });

    test('synthesizes factory for @assistedInject without @assistedFactory', () async {
      await runPipelineGolden(
        fixtureName: 'synthesized_simple',
        goldenDir: _goldenDir,
        expectFactory: true,
      );
    });

    test('runs analysis without errors for valid assisted declarations', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': _readFixtureSource('$_goldenDir/valid_pair.dart'),
      }, onLog: logs.add);

      expect(result.succeeded, isTrue);
      expect(logs.where((l) => l.level == Level.SEVERE), isEmpty, reason: 'No errors for valid assisted declarations');
    });

    test('generated output matches golden for valid assisted pair', () async {
      await runPipelineGolden(
        fixtureName: 'valid_pair',
        goldenDir: _goldenDir,
      );
    });

    test('aggregates multiple factories into a single deterministic output', () async {
      await runPipelineGolden(
        fixtureName: 'multiple_factories',
        goldenDir: _goldenDir,
      );
    });

    test('explicit @assistedFactory takes precedence over synthesized factory', () async {
      await runPipelineGolden(
        fixtureName: 'explicit_takes_precedence',
        goldenDir: _goldenDir,
      );
    });

    test('explicit @assistedFactory takes precedence over synthesized factory (multi-constructor)', () async {
      await runPipelineGolden(
        fixtureName: 'explicit_takes_precedence_multi',
        goldenDir: _goldenDir,
      );
    });

    test('mixed @inject and @assistedInject on same class', () async {
      await runPipelineGolden(
        fixtureName: 'mixed_inject_and_assisted',
        goldenDir: _goldenDir,
        expectFactory: true,
      );
    });

    test('reports diagnostic for @assistedInject with no @assisted parameters', () async {
      final logs = <LogRecord>[];
      await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              class Dep {}

              class BadService {
                @assistedInject
                BadService(Dep dep);
              }
            ''',
      }, onLog: logs.add);

      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('has no @assisted parameters')),
      );
    });

    test('reports diagnostic for non-abstract @assistedFactory class', () async {
      final logs = <LogRecord>[];
      await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              class MyService {
                @assistedInject
                MyService(@assisted String name);
              }

              @assistedFactory
              class NotAbstractFactory {
                MyService create(String name) => throw UnimplementedError();
              }
            ''',
      }, onLog: logs.add);

      expect(logs.where((l) => l.level == Level.SEVERE).map((l) => l.message), anyElement(contains('is not abstract')));
    });

    test('reports diagnostic for @assistedFactory with wrong return type', () async {
      final logs = <LogRecord>[];
      await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              class NotAssisted {}

              class MyService {
                @assistedInject
                MyService(@assisted String name);
              }

              @assistedFactory
              abstract class BadFactory {
                NotAssisted create(String name);
              }
            ''',
      }, onLog: logs.add);

      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('has no @assistedInject constructor')),
      );
    });

    test('reports diagnostic for @assistedFactory with parameter count mismatch', () async {
      final logs = <LogRecord>[];
      await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              class MyService {
                @assistedInject
                MyService(@assisted String name, @assisted int count);
              }

              @assistedFactory
              abstract class WrongCountFactory {
                MyService create(String name);
              }
            ''',
      }, onLog: logs.add);

      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('1 parameter(s) but the target constructor has 2')),
      );
    });

    test('reports error for multi-constructor @assistedInject with missing qualifiers', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              class MyService {
                @assistedInject
                MyService(@assisted String name);

                @assistedInject
                MyService.other(@assisted int count);
              }
            ''',
      }, onLog: logs.add);

      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('Multiple @assistedInject constructors')),
      );
      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('require unique @Qualifier annotations')),
      );
      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'factoryBuilder must not emit .factory.dart when validation fails',
      );
    });

    test('reports error for multi-constructor @assistedInject with duplicate qualifiers', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              const premium = Qualifier(#premium);

              class MyService {
                @premium
                @assistedInject
                MyService(@assisted String name);

                @premium
                @assistedInject
                MyService.other(@assisted int count);
              }
            ''',
      }, onLog: logs.add);

      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('Duplicate @Qualifier')),
      );
      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'factoryBuilder must not emit .factory.dart when validation fails',
      );
    });

    test('reports error for multi-constructor @assistedInject with partial qualifiers', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              const premium = Qualifier(#premium);

              class MyService {
                @premium
                @assistedInject
                MyService(@assisted String name);

                @assistedInject
                MyService.other(@assisted int count);
              }
            ''',
      }, onLog: logs.add);

      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('require unique @Qualifier annotations')),
      );
      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'factoryBuilder must not emit .factory.dart when validation fails',
      );
    });

    test('reports error for multi-constructor @assistedInject with invalid qualifier characters', () async {
      final logs = <LogRecord>[];
      final TestBuilderResult result = await testBuilder(builder, {
        ...injectAnnotationAssets,
        'pkg|lib/service.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              part 'service.factory.dart';

              // Symbol() constructor accepts arbitrary strings, including
              // ones that are not valid Dart identifier characters.
              const dashed = Qualifier(Symbol('foo-bar'));
              const other = Qualifier(#valid);

              class MyService {
                @dashed
                @assistedInject
                MyService(@assisted String name);

                @other
                @assistedInject
                MyService.other(@assisted int count);
              }
            ''',
      }, onLog: logs.add);

      expect(
        logs.where((l) => l.level == Level.SEVERE).map((l) => l.message),
        anyElement(contains('Invalid @Qualifier symbol')),
      );
      expect(
        result.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'factoryBuilder must not emit .factory.dart when qualifier content is invalid',
      );
    });
  });

  group('FactoryBuilder', () {
    test('can be instantiated', () {
      const builder = FactoryBuilder();
      expect(builder, isNotNull);
    });

    test('is a Generator', () {
      const builder = FactoryBuilder();
      expect(builder, isA<Generator>());
    });

    test('supports const construction', () {
      const builder = FactoryBuilder();
      expect(identical(const FactoryBuilder(), builder), isTrue);
    });

    test('toString returns canonical header', () {
      const builder = FactoryBuilder();
      expect(builder.toString(), 'inject.dart\nhttps://pub.dev/packages/inject_annotation');
    });
  });
}

String _readGeneratedFactoryOutput(dynamic result, String fileName) {
  final outputId = result.readerWriter.testing.assets.firstWhere((AssetId id) => id.path.endsWith(fileName));
  return result.readerWriter.testing.readString(outputId);
}

String _readFixtureSource(String path) => File(path).readAsStringSync();
