import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/inject_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../helpers/inject_annotation_stub.dart';

void main() {
  group('builder registration', () {
    const sourceCode = '''
      class PlainClass {
        final int value;
        PlainClass(this.value);
      }
    ''';

    // Task 3.1: both builders run sequentially without conflicts
    test('factoryBuilder and injectBuilder run sequentially without conflicts', () async {
      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions.empty);

      final TestBuilderResult factoryResult = await testBuilder(factory, {'pkg|lib/example.dart': sourceCode});
      expect(factoryResult.succeeded, isTrue);

      final TestBuilderResult injectResult = await testBuilder(inject, {'pkg|lib/example.dart': sourceCode});
      expect(injectResult.succeeded, isTrue);
    });

    // Task 3.2: neither builder produces output for a plain class
    test('neither builder produces output for a plain class', () async {
      final Builder factory = factoryBuilder(BuilderOptions.empty);
      final Builder inject = injectBuilder(BuilderOptions.empty);

      final TestBuilderResult factoryResult = await testBuilder(factory, {'pkg|lib/example.dart': sourceCode});
      expect(
        factoryResult.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'factoryBuilder must not produce .factory.dart for plain classes',
      );

      final TestBuilderResult injectResult = await testBuilder(inject, {'pkg|lib/example.dart': sourceCode});
      expect(
        injectResult.outputs.where((id) => id.path.endsWith('.inject.dart')),
        isEmpty,
        reason: 'injectBuilder must not produce .inject.dart for plain classes',
      );
    });

    // Task 3.3: injectBuilder returns a LibraryBuilder wrapping InjectBuilder
    test('injectBuilder returns a LibraryBuilder', () {
      final Builder builder = injectBuilder(BuilderOptions.empty);
      expect(builder, isA<LibraryBuilder>());
    });

    // Code Review Fix: verify both builders can run in sequence on annotated code
    test('factoryBuilder then injectBuilder succeed in order on annotated source', () async {
      final Map<String, String> source = {
        ...injectAnnotationAssets,
        'pkg|lib/app.dart': '''
            import 'package:inject_annotation/inject_annotation.dart';

            class PublicService {
              @inject
              PublicService();
            }

            @module
            class AppModule {
              @provides
              String provideName() => 'test';
            }

            @Component([AppModule])
            abstract class CoffeeShop {
              @inject
              PublicService get service;
            }
          ''',
      };

      // Step 1: factoryBuilder runs first — no factory output expected (no @assistedInject)
      final TestBuilderResult factoryResult = await testBuilder(factoryBuilder(BuilderOptions.empty), source);
      expect(factoryResult.succeeded, isTrue);
      expect(
        factoryResult.outputs.where((id) => id.path.endsWith('.factory.dart')),
        isEmpty,
        reason: 'No @assistedInject → no factory output',
      );

      // Step 2: injectBuilder runs after — must succeed and produce .inject.dart
      final TestBuilderResult injectResult = await testBuilder(injectBuilder(BuilderOptions.empty), source);
      expect(injectResult.succeeded, isTrue);
      expect(
        injectResult.outputs.where((id) => id.path.endsWith('.inject.dart')),
        isNotEmpty,
        reason: 'injectBuilder must produce .inject.dart for @component source',
      );
    });
  });
}
