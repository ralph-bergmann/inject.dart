import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/inject_generator.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../helpers/inject_annotation_stub.dart';

void main() {
  group('InjectBuilder', () {
    group('instantiation', () {
      test('can be instantiated', () {
        final builder = InjectBuilder();
        expect(builder, isNotNull);
      });

      test('is a Generator', () {
        final builder = InjectBuilder();
        expect(builder, isA<Generator>());
      });

      test('can be constructed with default options', () {
        final builder = InjectBuilder();
        expect(builder.options, equals(InjectBuilderOptions.defaults));
      });
    });

    group('generate', () {
      late Builder builder;

      setUp(() {
        builder = LibraryBuilder(InjectBuilder(), generatedExtension: '.inject.dart');
      });

      test('returns null for a library with no inject annotations', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          'pkg|lib/example.dart': '''
              class Foo {}
            ''',
        });

        // No output expected — generator returns null for unannotated code.
        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
      });

      test('does not create or depend on summary.json', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          'pkg|lib/example.dart': '''
              class Bar {}
            ''',
        });

        // Verify no summary.json was written.
        expect(
          result.outputs.where((id) => id.path.contains('summary.json')),
          isEmpty,
          reason: 'InjectBuilder must not create or depend on summary.json',
        );
      });

      test('completes pipeline in a single pass without errors', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          'pkg|lib/example.dart': '''
              class Baz {}
            ''',
        });

        // Pipeline completed successfully in a single pass.
        expect(result.succeeded, isTrue);
      });

      // Task 2.3: error-suppression path
      test('suppresses codegen and returns null when reporter has errors', () async {
        final errorBuilder = LibraryBuilder(_ErrorInjectBuilder(), generatedExtension: '.inject.dart');

        final TestBuilderResult result = await testBuilder(errorBuilder, {
          'pkg|lib/example.dart': '''
              class Foo {}
            ''',
        });

        // Codegen suppressed — no .inject.dart output.
        expect(
          result.outputs.where((id) => id.path.endsWith('.inject.dart')),
          isEmpty,
          reason: 'Codegen must be suppressed when reporter has errors',
        );
        // SEVERE-level logging causes the build to be marked as failed —
        // the correct outcome when fatal errors are reported.
        expect(result.succeeded, isFalse);
      });

      // Task 2.4: no-error path proceeds to codegen phase
      test('proceeds to codegen phase when reporter has no errors', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          'pkg|lib/example.dart': '''
              class Qux {}
            ''',
        });

        // Error guard not triggered — pipeline proceeds past the error gate.
        // The input has no injectable annotations, so no output is created.
        expect(result.succeeded, isTrue);
        expect(
          result.outputs.where((id) => id.path.endsWith('.inject.dart')),
          isEmpty,
          reason: 'No injectable annotations — no output is generated',
        );
      });

      // Task 2.5: warnings do not block codegen
      test('does not block codegen when reporter has only warnings', () async {
        final warningBuilder = LibraryBuilder(_WarningInjectBuilder(), generatedExtension: '.inject.dart');

        final TestBuilderResult result = await testBuilder(warningBuilder, {
          'pkg|lib/example.dart': '''
              class Quux {}
            ''',
        });

        // Warnings do not block codegen — pipeline proceeds and succeeds.
        expect(result.succeeded, isTrue);
        // No injectable annotations — no output is generated.
        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
      });
    });

    group('factory functions', () {
      test('injectBuilder returns a Builder', () {
        final Builder result = injectBuilder(BuilderOptions.empty);
        expect(result, isA<Builder>());
      });

      test('factoryBuilder returns a Builder', () {
        final Builder result = factoryBuilder(BuilderOptions.empty);
        expect(result, isA<Builder>());
      });
    });

    group('validation integration', () {
      late Builder builder;

      setUp(() {
        builder = LibraryBuilder(InjectBuilder(), generatedExtension: '.inject.dart');
      });

      test('blocks codegen when validation reports fatal errors', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              class _PrivateService {}

              @component
              abstract class CoffeeShop {
                @inject
                _PrivateService get service;
              }
            ''',
        });

        // Validation reports private symbol error — codegen blocked.
        expect(
          result.outputs.where((id) => id.path.endsWith('.inject.dart')),
          isEmpty,
          reason: 'Codegen must be blocked when validation finds private symbols',
        );
        expect(result.succeeded, isFalse);
      });

      test('proceeds to codegen when validation passes', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
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
        });

        // Validation passes — codegen proceeds.
        expect(result.succeeded, isTrue);
        expect(
          result.outputs.where((id) => id.path.endsWith('.inject.dart')),
          isNotEmpty,
          reason: 'Codegen should proceed when validation passes',
        );
      });

      test('blocks codegen for private module provider methods', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @module
              class AppModule {
                @provides
                String _provideName() => 'test';
              }

              @Component([AppModule])
              abstract class CoffeeShop {
                @inject
                String get service;
              }
            ''',
        });

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
        expect(result.succeeded, isFalse);
      });

      test('blocks codegen when @Component lists a mixin as a module', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @module
              mixin AppModule {
                @provides
                String provideName() => 'test';
              }

              @Component([AppModule])
              abstract class CoffeeShop {
                @inject
                String get name;
              }
            ''',
        });

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
        expect(result.succeeded, isFalse);
      });

      test('blocks codegen when @Component lists an enum as a module', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @module
              enum AppModule { a, b }

              @Component([AppModule])
              abstract class CoffeeShop {
                @inject
                String get name;
              }
            ''',
        });

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
        expect(result.succeeded, isFalse);
      });

      test('blocks codegen when @Component uses a private @module class', () async {
        final logs = <LogRecord>[];
        final TestBuilderResult result = await testBuilder(
          builder,
          {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @module
              class _AppModule {
                @provides
                String provideName() => 'test';
              }

              @Component([_AppModule])
              abstract class AppComponent {
                @inject
                String get name;
              }
            ''',
          },
          onLog: logs.add,
        );

        expect(
          result.outputs.where((id) => id.path.endsWith('.inject.dart')),
          isEmpty,
          reason: 'Private @module class must block codegen',
        );
        expect(result.succeeded, isFalse);
        final List<String> severeMessages =
            logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
        expect(
          severeMessages,
          anyElement(contains('must be public')),
          reason: 'Expected SEVERE diagnostic with "must be public" wording',
        );
      });

      test('blocks codegen for private transitive dependency behind module provider', () async {
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              class _Secret {}

              @inject
              class PublicService {
                PublicService(_Secret secret);
              }

              @module
              class AppModule {
                @provides
                String provideName(PublicService service) => 'test';
              }

              @Component([AppModule])
              abstract class CoffeeShop {
                @inject
                String get name;
              }
            ''',
        });

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
        expect(result.succeeded, isFalse);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles — override createReporter() to inject pre-populated reporters.
// ---------------------------------------------------------------------------

/// [InjectBuilder] subclass that pre-loads one error into the reporter.
/// Used to test the error-suppression path (Task 2.3).
class _ErrorInjectBuilder extends InjectBuilder {
  _ErrorInjectBuilder();

  @override
  DiagnosticReporter createReporter() => DiagnosticReporter()
    ..error(
      filePath: 'test.dart',
      line: 1,
      column: 1,
      message: 'Simulated fatal error for testing.',
      suggestion: 'Fix the error.',
    );
}

/// [InjectBuilder] subclass that pre-loads one warning into the reporter.
/// Used to test the warning-only path (Task 2.5).
class _WarningInjectBuilder extends InjectBuilder {
  _WarningInjectBuilder();

  @override
  DiagnosticReporter createReporter() => DiagnosticReporter()
    ..warning(
      filePath: 'test.dart',
      line: 1,
      column: 1,
      message: 'Simulated non-fatal warning for testing.',
      suggestion: 'Consider fixing the warning.',
    );
}
