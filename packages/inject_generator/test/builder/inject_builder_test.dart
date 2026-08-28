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

    group('subcomponent orphan warning', () {
      test('warns when a @subcomponent is declared but never installed', () async {
        final logs = <LogRecord>[];

        final Builder factory = factoryBuilder(BuilderOptions.empty);
        final Builder inject = injectBuilder(BuilderOptions.empty);

        final TestBuilderResult result = await testBuilders(
          [factory, inject],
          {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                part 'example.factory.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class OrphanSubcomponent {
                  ApiService get apiService;
                }

                @component
                abstract class AppComponent {
                  ApiService get apiService;
                }
              """,
          },
          rootPackage: 'pkg',
          visibleOutputBuilders: {factory},
          appliesBuilders: {
            factory: ['inject_generator|inject_builder'],
          },
          flattenOutput: true,
          onLog: logs.add,
        );

        expect(result.succeeded, isTrue, reason: 'orphan is a warning, not an error');
        final List<String> warnings = logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
        expect(
          warnings,
          anyElement(contains("Subcomponent 'OrphanSubcomponent' is declared but never installed")),
          reason: warnings.join('\n'),
        );
      });

      test('does not warn when the subcomponent is installed by a local module', () async {
        final logs = <LogRecord>[];

        final Builder factory = factoryBuilder(BuilderOptions.empty);
        final Builder inject = injectBuilder(BuilderOptions.empty);

        await testBuilders(
          [factory, inject],
          {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                part 'example.factory.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }

                @Module(subcomponents: [HttpSubcomponent])
                class NetworkModule {}

                @Component([NetworkModule])
                abstract class AppComponent {
                  ApiService get apiService;
                  HttpSubcomponentFactory get httpFactory;
                }
              """,
          },
          rootPackage: 'pkg',
          visibleOutputBuilders: {factory},
          appliesBuilders: {
            factory: ['inject_generator|inject_builder'],
          },
          flattenOutput: true,
          onLog: logs.add,
        );

        final List<String> warnings = logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
        expect(
          warnings.where((w) => w.contains('never installed')),
          isEmpty,
          reason: warnings.join('\n'),
        );
      });

      test(
        'does not warn when the subcomponent is installed by a module in a different file of the same package',
        () async {
          final logs = <LogRecord>[];

          final Builder factory = factoryBuilder(BuilderOptions.empty);
          final Builder inject = injectBuilder(BuilderOptions.empty);

          await testBuilders(
            [factory, inject],
            {
              ...injectAnnotationAssets,
              // The `@subcomponent` lives in its own file, with no `@Component`
              // of its own — this is the "library-author" composition pattern
              // the README advertises: a feature file declares its subcomponent,
              // an unrelated app file installs it.
              'pkg|lib/http_feature.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                part 'http_feature.factory.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }
              """,
              'pkg|lib/app.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                import 'http_feature.dart';

                @Module(subcomponents: [HttpSubcomponent])
                class NetworkModule {}

                @Component([NetworkModule])
                abstract class AppComponent {
                  HttpSubcomponentFactory get httpFactory;
                }
              """,
            },
            rootPackage: 'pkg',
            visibleOutputBuilders: {factory},
            appliesBuilders: {
              factory: ['inject_generator|inject_builder'],
            },
            flattenOutput: true,
            onLog: logs.add,
          );

          final List<String> warnings = logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
          expect(
            warnings.where((w) => w.contains('never installed')),
            isEmpty,
            reason: warnings.join('\n'),
          );
        },
      );
    });

    group('subcomponentFactory never-installed warning', () {
      test('warns at the factory when its target subcomponent is never installed anywhere', () async {
        final logs = <LogRecord>[];

        final Builder factory = factoryBuilder(BuilderOptions.empty);
        final Builder inject = injectBuilder(BuilderOptions.empty);

        final TestBuilderResult result = await testBuilders(
          [factory, inject],
          {
            ...injectAnnotationAssets,
            // The subcomponent lives in its own file; the factory in another
            // file targets it, but no module anywhere installs it — the
            // factory can never produce anything.
            'pkg|lib/http_feature.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                part 'http_feature.factory.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }
              """,
            'pkg|lib/app.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                import 'http_feature.dart';

                @subcomponentFactory
                abstract class HttpFactory {
                  HttpSubcomponent create();
                }
              """,
          },
          rootPackage: 'pkg',
          visibleOutputBuilders: {factory},
          appliesBuilders: {
            factory: ['inject_generator|inject_builder'],
          },
          flattenOutput: true,
          onLog: logs.add,
        );

        expect(result.succeeded, isTrue, reason: 'a never-installed factory target is a warning, not an error');
        final List<String> warnings = logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
        expect(
          warnings,
          anyElement(
            allOf(
              contains("'HttpFactory'"),
              contains("'HttpSubcomponent'"),
              contains('never installed'),
              contains('has no effect'),
            ),
          ),
          reason: warnings.join('\n'),
        );
      });

      test(
        'orphan subcomponent with a factory in the same library produces one combined warning, not two',
        () async {
          final logs = <LogRecord>[];

          final Builder factory = factoryBuilder(BuilderOptions.empty);
          final Builder inject = injectBuilder(BuilderOptions.empty);

          final TestBuilderResult result = await testBuilders(
            [factory, inject],
            {
              ...injectAnnotationAssets,
              'pkg|lib/example.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }

                @subcomponentFactory
                abstract class HttpFactory {
                  HttpSubcomponent create();
                }

                @component
                abstract class AppComponent {
                  ApiService get apiService;
                }
              """,
            },
            rootPackage: 'pkg',
            visibleOutputBuilders: {factory},
            appliesBuilders: {
              factory: ['inject_generator|inject_builder'],
            },
            flattenOutput: true,
            onLog: logs.add,
          );

          expect(result.succeeded, isTrue, reason: 'orphan + inert factory are warnings, not errors');
          final List<String> warnings = logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
          final List<String> installWarnings = warnings
              .where((w) => w.contains('never installed') || w.contains('has no effect'))
              .toList();
          expect(
            installWarnings,
            hasLength(1),
            reason:
                'the orphan subcomponent and its inert factory describe the same root cause and '
                'must be reported as one combined warning:\n${warnings.join('\n')}',
          );
          expect(installWarnings.single, contains("Subcomponent 'HttpSubcomponent' is declared but never installed"));
          expect(installWarnings.single, contains("'HttpFactory'"));
          expect(installWarnings.single, contains('has no effect'));
        },
      );

      test('does not warn when the target subcomponent is installed in the same file', () async {
        final logs = <LogRecord>[];

        final Builder factory = factoryBuilder(BuilderOptions.empty);
        final Builder inject = injectBuilder(BuilderOptions.empty);

        final TestBuilderResult result = await testBuilders(
          [factory, inject],
          {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }

                @subcomponentFactory
                abstract class HttpFactory {
                  HttpSubcomponent create();
                }

                @Module(subcomponents: [HttpSubcomponent])
                class NetworkModule {}

                @Component([NetworkModule])
                abstract class AppComponent {
                  ApiService get apiService;
                  HttpFactory get httpFactory;
                }
              """,
          },
          rootPackage: 'pkg',
          visibleOutputBuilders: {factory},
          appliesBuilders: {
            factory: ['inject_generator|inject_builder'],
          },
          flattenOutput: true,
          onLog: logs.add,
        );

        expect(result.succeeded, isTrue, reason: logs.map((l) => l.message).join('\n'));
        final List<String> warnings = logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
        expect(
          warnings.where((w) => w.contains('never installed') || w.contains('has no effect')),
          isEmpty,
          reason: warnings.join('\n'),
        );
      });

      test(
        'does not warn when the factory targets a subcomponent installed in a different file of the same package',
        () async {
          final logs = <LogRecord>[];

          final Builder factory = factoryBuilder(BuilderOptions.empty);
          final Builder inject = injectBuilder(BuilderOptions.empty);

          final TestBuilderResult result = await testBuilders(
            [factory, inject],
            {
              ...injectAnnotationAssets,
              'pkg|lib/http_feature.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }

                @subcomponentFactory
                abstract class HttpSubcomponentFactory {
                  HttpSubcomponent create();
                }
              """,
              'pkg|lib/app.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                import 'http_feature.dart';

                @Module(subcomponents: [HttpSubcomponent])
                class NetworkModule {}

                @Component([NetworkModule])
                abstract class AppComponent {
                  HttpSubcomponentFactory get httpFactory;
                }
              """,
            },
            rootPackage: 'pkg',
            visibleOutputBuilders: {factory},
            appliesBuilders: {
              factory: ['inject_generator|inject_builder'],
            },
            flattenOutput: true,
            onLog: logs.add,
          );

          expect(result.succeeded, isTrue, reason: logs.map((l) => l.message).join('\n'));
          final List<String> warnings = logs.where((l) => l.level == Level.WARNING).map((l) => l.message).toList();
          expect(
            warnings.where((w) => w.contains('never installed') || w.contains('has no effect')),
            isEmpty,
            reason: warnings.join('\n'),
          );
        },
      );
    });

    group('subcomponent module-list diagnostics are not duplicated across builder passes', () {
      // `factory_builder` and `inject_builder` both read `@Subcomponent([...])`
      // (the former to generate the abstract factory, the latter — once the
      // subcomponent is actually installed — to collect entry points).
      // `readSubcomponent`'s `validate: false` in `discoverSubcomponentFactories`
      // must prevent the same module-list problem from being reported twice.
      test('reports a duplicate module in @Subcomponent([...]) exactly once', () async {
        final logs = <LogRecord>[];

        final Builder factory = factoryBuilder(BuilderOptions.empty);
        final Builder inject = injectBuilder(BuilderOptions.empty);

        await testBuilders(
          [factory, inject],
          {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                part 'example.factory.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @module
                class HttpModule {}

                @Subcomponent([HttpModule, HttpModule])
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }

                @Module(subcomponents: [HttpSubcomponent])
                class NetworkModule {}

                @Component([NetworkModule])
                abstract class AppComponent {
                  ApiService get apiService;
                  HttpSubcomponentFactory get httpFactory;
                }
              """,
          },
          rootPackage: 'pkg',
          visibleOutputBuilders: {factory},
          appliesBuilders: {
            factory: ['inject_generator|inject_builder'],
          },
          flattenOutput: true,
          onLog: logs.add,
        );

        final List<String> errors = logs
            .where((l) => l.level == Level.SEVERE)
            .map((l) => l.message)
            .where((m) => m.contains('listed more than once in @Subcomponent'))
            .toList();
        expect(errors, hasLength(1), reason: errors.join('\n'));
      });

      test('a @subcomponent listed in the @Component module list fails the build with exactly one error', () async {
        final logs = <LogRecord>[];

        final Builder factory = factoryBuilder(BuilderOptions.empty);
        final Builder inject = injectBuilder(BuilderOptions.empty);

        final TestBuilderResult result = await testBuilders(
          [factory, inject],
          {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                part 'example.factory.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class HttpSubcomponent {
                  ApiService get apiService;
                }

                // Classic Dagger-migration mistake: the subcomponent is listed
                // like a module instead of being installed through
                // @Module(subcomponents: [...]).
                @Component([HttpSubcomponent])
                abstract class AppComponent {
                  ApiService get apiService;
                }
              """,
          },
          rootPackage: 'pkg',
          visibleOutputBuilders: {factory},
          appliesBuilders: {
            factory: ['inject_generator|inject_builder'],
          },
          flattenOutput: true,
          onLog: logs.add,
        );

        expect(result.succeeded, isFalse, reason: 'a @subcomponent in the module list must fail the build');
        expect(
          result.outputs.where((id) => id.path.endsWith('.inject.dart')),
          isEmpty,
          reason: 'the error must suppress .inject.dart output',
        );
        final List<String> errors = logs
            .where((l) => l.level == Level.SEVERE)
            .map((l) => l.message)
            .where((m) => m.contains('annotated with @subcomponent') && m.contains('HttpSubcomponent'))
            .toList();
        expect(errors, hasLength(1), reason: errors.join('\n'));
        expect(errors.single, contains('@Module(subcomponents: [HttpSubcomponent])'));
      });

      test(
        'a @subcomponent listed in another @Subcomponent module list fails the build with exactly one error',
        () async {
          final logs = <LogRecord>[];

          final Builder factory = factoryBuilder(BuilderOptions.empty);
          final Builder inject = injectBuilder(BuilderOptions.empty);

          final TestBuilderResult result = await testBuilders(
            [factory, inject],
            {
              ...injectAnnotationAssets,
              'pkg|lib/example.dart': """
                import 'package:inject_annotation/inject_annotation.dart';

                part 'example.factory.dart';

                class ApiService {
                  @inject
                  const ApiService();
                }

                @subcomponent
                abstract class InnerSubcomponent {
                  ApiService get apiService;
                }

                @Subcomponent([InnerSubcomponent])
                abstract class OuterSubcomponent {
                  ApiService get apiService;
                }

                @Module(subcomponents: [OuterSubcomponent])
                class NetworkModule {}

                @Component([NetworkModule])
                abstract class AppComponent {
                  ApiService get apiService;
                  OuterSubcomponentFactory get outerFactory;
                }
              """,
            },
            rootPackage: 'pkg',
            visibleOutputBuilders: {factory},
            appliesBuilders: {
              factory: ['inject_generator|inject_builder'],
            },
            flattenOutput: true,
            onLog: logs.add,
          );

          expect(result.succeeded, isFalse, reason: 'a @subcomponent in the module list must fail the build');
          final List<String> errors = logs
              .where((l) => l.level == Level.SEVERE)
              .map((l) => l.message)
              .where((m) => m.contains('annotated with @subcomponent') && m.contains('InnerSubcomponent'))
              .toList();
          expect(errors, hasLength(1), reason: errors.join('\n'));
        },
      );
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
        final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
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

      test('reports error for @assistedInject constructor on a @Component class', () async {
        final logs = <LogRecord>[];
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @component
              abstract class CoffeeShop {
                @assistedInject
                CoffeeShop();
              }
            ''',
        }, onLog: logs.add);

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
        expect(result.succeeded, isFalse);
        final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
        expect(
          severeMessages,
          anyElement(
            allOf(
              contains("@Component class 'CoffeeShop' declares an @assistedInject constructor"),
              contains(RegExp(r':\d+:\d+')),
            ),
          ),
          reason: 'Expected element-located SEVERE diagnostic naming the offending class',
        );
      });

      test('reports error for @inject constructor on a @Component class', () async {
        final logs = <LogRecord>[];
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @component
              abstract class CoffeeShop {
                @inject
                CoffeeShop();
              }
            ''',
        }, onLog: logs.add);

        expect(result.outputs.where((id) => id.path.endsWith('.inject.dart')), isEmpty);
        expect(result.succeeded, isFalse);
        final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
        expect(
          severeMessages,
          anyElement(
            allOf(
              contains("@Component class 'CoffeeShop' declares an @inject constructor"),
              contains(RegExp(r':\d+:\d+')),
            ),
          ),
          reason: 'Expected element-located SEVERE diagnostic naming the offending class',
        );
      });

      test('reports a cycle when @Module(includes: ...) forms a loop', () async {
        final logs = <LogRecord>[];
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @Module(includes: [ModuleB])
              class ModuleA {}

              @Module(includes: [ModuleA])
              class ModuleB {}

              @Component([ModuleA])
              abstract class AppComponent {}
            ''',
        }, onLog: logs.add);

        expect(
          result.outputs.where((id) => id.path.endsWith('.inject.dart')),
          isEmpty,
          reason: 'A module include cycle must block codegen',
        );
        expect(result.succeeded, isFalse);
        final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
        expect(
          severeMessages,
          anyElement(contains('cycle')),
          reason: 'Expected a SEVERE diagnostic naming the include cycle',
        );
      });

      test('does not report a cycle for a diamond include (same module via two paths)', () async {
        final logs = <LogRecord>[];
        final TestBuilderResult result = await testBuilder(builder, {
          ...injectAnnotationAssets,
          'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @module
              class SharedModule {
                @provides
                String provideName() => 'shared';
              }

              @Module(includes: [SharedModule])
              class ModuleB {}

              @Module(includes: [SharedModule])
              class ModuleC {}

              @Module(includes: [ModuleB, ModuleC])
              class Umbrella {}

              @Component([Umbrella])
              abstract class AppComponent {
                @inject
                String get name;
              }
            ''',
        }, onLog: logs.add);

        expect(result.succeeded, isTrue);
        final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
        expect(severeMessages, isEmpty);
      });

      test(
        'two distinct sibling included modules providing the same binding key resolve via '
        'declaration-order override, mirroring top-level module precedence (no duplicate-binding error)',
        () async {
          final logs = <LogRecord>[];
          final TestBuilderResult result = await testBuilder(builder, {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @module
              class X {
                @provides
                String provideName() => 'x';
              }

              @module
              class Y {
                @provides
                String provideName() => 'y';
              }

              @Module(includes: [X, Y])
              class Umbrella {}

              @Component([Umbrella])
              abstract class AppComponent {
                @inject
                String get name;
              }
            ''',
          }, onLog: logs.add);

          expect(
            result.succeeded,
            isTrue,
            reason:
                'Two sibling included modules providing the same key must resolve via the existing '
                'declaration-order override rule (last listed wins), the same as two directly-listed '
                'sibling modules — not a new duplicate-binding error.',
          );
          final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
          expect(severeMessages, isEmpty);

          final AssetId injectOutputId = result.readerWriter.testing.assets.firstWhere(
            (id) => id.path.endsWith('.inject.dart'),
          );
          final String injectOutput = result.readerWriter.testing.readString(injectOutputId);
          expect(
            injectOutput,
            contains('final _i1.Y _module;'),
            reason: 'Y is declared last in includes: [X, Y], so its provider must win the override.',
          );
        },
      );

      test(
        'a directly-listed module always outranks a module reached only through a different, '
        'later-listed umbrella module\'s includes (direct-over-included precedence is absolute, '
        'not position-dependent)',
        () async {
          final logs = <LogRecord>[];
          final TestBuilderResult result = await testBuilder(builder, {
            ...injectAnnotationAssets,
            'pkg|lib/example.dart': '''
              import 'package:inject_annotation/inject_annotation.dart';

              @module
              class DirectModule {
                @provides
                String provideName() => 'direct';
              }

              @module
              class Shared {
                @provides
                String provideName() => 'shared';
              }

              @Module(includes: [Shared])
              class Umbrella {}

              @Component([DirectModule, Umbrella])
              abstract class AppComponent {
                @inject
                String get name;
              }
            ''',
          }, onLog: logs.add);

          expect(result.succeeded, isTrue);
          final List<String> severeMessages = logs.where((l) => l.level == Level.SEVERE).map((l) => l.message).toList();
          expect(severeMessages, isEmpty);

          final AssetId injectOutputId = result.readerWriter.testing.assets.firstWhere(
            (id) => id.path.endsWith('.inject.dart'),
          );
          final String injectOutput = result.readerWriter.testing.readString(injectOutputId);
          expect(
            injectOutput,
            contains('final _i1.DirectModule _module;'),
            reason:
                'DirectModule is directly listed on @Component; Shared is only reachable through '
                "Umbrella's includes: — the directly-listed module must win even though Umbrella "
                '(and therefore Shared) is declared after DirectModule.',
          );
        },
      );
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
