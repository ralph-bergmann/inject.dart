import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/builder/inject_builder_options.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/async_propagator.dart';
import 'package:inject_generator/src/validation/binding_graph_result.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:inject_generator/src/validation/entry_point_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late BindingResolver resolver;
  final propagator = AsyncPropagator();
  late EntryPointValidator validator;

  setUp(() {
    reporter = DiagnosticReporter();
    resolver = BindingResolver(reporter: reporter);
    validator = EntryPointValidator(reporter: reporter);
  });

  group('EntryPointValidator', () {
    // sync getter on async chain → error
    test('reports error for sync entry-point getter with async chain', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        @inject
        class Repository {
          Repository(this.db);
          final Database db;
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          @inject
          Repository get repository;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final repoClass = library.getClass('Repository')!;
      final repoData = reader.readInjectable(repoClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [(classElement: repoClass, injectable: repoData)],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.hasErrors, isTrue);
      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          "Component getter 'repository' is declared synchronous but its dependency chain is asynchronous."
          " The async provider 'DbModule.provideDatabase' in the dependency chain"
          ' causes transitive async propagation.',
        ),
      );
      expect(
        msg.suggestion,
        equals("Change the getter return type from 'Repository' to 'Future<Repository>'."),
      );
    });

    // exact diagnostic text
    test('diagnostic text matches the documented schema exactly', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        @inject
        class Repository {
          Repository(this.db);
          final Database db;
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          @inject
          Repository get repository;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final repoClass = library.getClass('Repository')!;
      final repoData = reader.readInjectable(repoClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [(classElement: repoClass, injectable: repoData)],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          "Component getter 'repository' is declared synchronous but its dependency chain is asynchronous."
          " The async provider 'DbModule.provideDatabase' in the dependency chain"
          ' causes transitive async propagation.',
        ),
      );
      expect(
        msg.suggestion,
        equals("Change the getter return type from 'Repository' to 'Future<Repository>'."),
      );
    });

    test('directly-async entry-point names the binding itself as the async root', () async {
      // Sync getter on a directly-async binding (no transitive chain): the
      // diagnostic must still surface the async provider rather than dropping
      // the rootInfo entirely.
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          Database get database;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          "Component getter 'database' is declared synchronous but its dependency chain is asynchronous."
          " The provider 'DbModule.provideDatabase' is asynchronous.",
        ),
      );
      expect(
        msg.suggestion,
        equals("Change the getter return type from 'Database' to 'Future<Database>'."),
      );
    });

    // Future<T> getter on async chain → no error
    test('allows Future<T> entry-point getter with async chain', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        @inject
        class Repository {
          Repository(this.db);
          final Database db;
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          @inject
          Future<Repository> get repository;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final repoClass = library.getClass('Repository')!;
      final repoData = reader.readInjectable(repoClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [(classElement: repoClass, injectable: repoData)],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.hasErrors, isFalse);
    });

    // Provider<T> getter on async chain → error
    test('reports error for Provider<T> entry-point getter with async chain', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        @inject
        class Repository {
          Repository(this.db);
          final Database db;
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          @inject
          Provider<Repository> get repository;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final repoClass = library.getClass('Repository')!;
      final repoData = reader.readInjectable(repoClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [(classElement: repoClass, injectable: repoData)],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          "Component getter 'repository' is declared synchronous but its dependency chain is asynchronous."
          " The async provider 'DbModule.provideDatabase' in the dependency chain"
          ' causes transitive async propagation.',
        ),
      );
      expect(
        msg.suggestion,
        equals("Change the getter return type from 'Provider<Repository>' to 'Provider<Future<Repository>>'."),
      );
    });

    test('an unbound Future<T> getter reports only the resolver error', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Unbound {}

        @Component([])
        abstract class AppComponent {
          Future<Unbound> get x;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(modules: [], injectables: [], entryPoints: componentData.entryPoints);
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.messages.single.message, contains("No binding found for entry-point type 'Unbound'"));
    });

    test('a Future<T> getter over a chain with a missing binding reports only the resolver error', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Db {}

        @inject
        class Repository {
          Repository(this.db);
          final Db db;
        }

        @Component([])
        abstract class AppComponent {
          Future<Repository> get repository;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final repoClass = library.getClass('Repository')!;
      final repoData = reader.readInjectable(repoClass)!;
      final componentData = reader.readComponent(library.getClass('AppComponent')!)!;

      final graphResult = resolver.resolve(
        modules: [],
        injectables: [(classElement: repoClass, injectable: repoData)],
        entryPoints: componentData.entryPoints,
      );
      validator.validate(propagator.propagate(graphResult), componentData.entryPoints);

      expect(reporter.messages.single.message, contains("No binding found for type 'Db'"));
    });

    group('a Provider getter whose wrapper matches its binding', () {
      const asyncFoo = '''
        @provides
        @asynchronous
        Future<Foo> provideFoo() async => Foo();
      ''';
      const syncFoo = '''
        @provides
        Foo provideFoo() => Foo();
      ''';

      Future<void> validateGetter(String provider, String getter) async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Foo {}

          @module
          class AppModule {
            $provider
          }

          @Component([AppModule])
          abstract class AppComponent {
            $getter
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final componentData = reader.readComponent(library.getClass('AppComponent')!)!;

        final graphResult = resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );
        validator.validate(propagator.propagate(graphResult), componentData.entryPoints);
      }

      test('allows Provider<Future<T>> over an async chain', () async {
        await validateGetter(asyncFoo, 'Provider<Future<Foo>> get foo;');

        expect(reporter.hasErrors, isFalse);
      });

      test('allows Provider<Future<T?>> over an async T', () async {
        await validateGetter(asyncFoo, 'Provider<Future<Foo?>> get foo;');

        expect(reporter.hasErrors, isFalse);
      });

      test('allows Provider<T> over a sync chain', () async {
        await validateGetter(syncFoo, 'Provider<Foo> get foo;');

        expect(reporter.hasErrors, isFalse);
      });
    });

    test('sync and Provider<T> getters over one async root report one aggregated error', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Db> provideDb() => Future.value(Db());
        }

        class Db {}

        @Component([DbModule])
        abstract class AppComponent {
          Db get a;
          Provider<Db> get b;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          'Component entry points [a, b] are declared synchronous but their dependency chain is asynchronous.'
          " The provider 'DbModule.provideDb' is asynchronous.",
        ),
      );
      expect(
        msg.suggestion,
        equals("Change return types: 'Db' → 'Future<Db>'; 'Provider<Db>' → 'Provider<Future<Db>>'."),
      );
    });

    // sync getter on sync chain → no error
    test('allows sync entry-point getter with sync chain', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class AppModule {
          @provides
          Database provideDatabase() => Database();
        }

        @inject
        class Repository {
          Repository(this.db);
          final Database db;
        }

        class Database {}

        @Component([AppModule])
        abstract class AppComponent {
          @inject
          Repository get repository;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('AppModule')!;
      final moduleData = reader.readModule(moduleClass);
      final repoClass = library.getClass('Repository')!;
      final repoData = reader.readInjectable(repoClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [(classElement: repoClass, injectable: repoData)],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.hasErrors, isFalse);
    });

    // edge case: two sync getters on distinct async roots → two separate diagnostics
    test('reports distinct errors for each sync entry-point on async chain', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class ModuleA {
          @provides
          @asynchronous
          Future<ServiceA> provideServiceA() => Future.value(ServiceA());
        }

        @module
        class ModuleB {
          @provides
          @asynchronous
          Future<ServiceB> provideServiceB() => Future.value(ServiceB());
        }

        @inject
        class HandlerA {
          HandlerA(this.service);
          final ServiceA service;
        }

        @inject
        class HandlerB {
          HandlerB(this.service);
          final ServiceB service;
        }

        class ServiceA {}
        class ServiceB {}

        @Component([ModuleA, ModuleB])
        abstract class AppComponent {
          HandlerA get handlerA;
          HandlerB get handlerB;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleAClass = library.getClass('ModuleA')!;
      final moduleAData = reader.readModule(moduleAClass);
      final moduleBClass = library.getClass('ModuleB')!;
      final moduleBData = reader.readModule(moduleBClass);
      final handlerAClass = library.getClass('HandlerA')!;
      final handlerAData = reader.readInjectable(handlerAClass)!;
      final handlerBClass = library.getClass('HandlerB')!;
      final handlerBData = reader.readInjectable(handlerBClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [
          (moduleClass: moduleAClass, moduleData: moduleAData),
          (moduleClass: moduleBClass, moduleData: moduleBData),
        ],
        injectables: [
          (classElement: handlerAClass, injectable: handlerAData),
          (classElement: handlerBClass, injectable: handlerBData),
        ],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.hasErrors, isTrue);
      expect(reporter.errorCount, equals(2));
      expect(reporter.messages.any((m) => m.message.contains("'handlerA'")), isTrue);
      expect(reporter.messages.any((m) => m.message.contains("'handlerB'")), isTrue);
    });

    // boundary (N=2): two sync getters sharing one async root → one aggregated diagnostic
    test('emits one aggregated diagnostic for N=2 sync getters on the same async root', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        @inject
        class ServiceA {
          ServiceA(this.db);
          final Database db;
        }

        @inject
        class ServiceB {
          ServiceB(this.db);
          final Database db;
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          ServiceA get serviceA;
          ServiceB get serviceB;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final serviceAClass = library.getClass('ServiceA')!;
      final serviceAData = reader.readInjectable(serviceAClass)!;
      final serviceBClass = library.getClass('ServiceB')!;
      final serviceBData = reader.readInjectable(serviceBClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [
          (classElement: serviceAClass, injectable: serviceAData),
          (classElement: serviceBClass, injectable: serviceBData),
        ],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.hasErrors, isTrue);
      expect(reporter.errorCount, equals(1));
      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          'Component entry points [serviceA, serviceB] are declared synchronous but their dependency chain is asynchronous.'
          " The async provider 'DbModule.provideDatabase' in the dependency chain"
          ' causes transitive async propagation.',
        ),
      );
      expect(
        msg.suggestion,
        equals("Change return types: 'ServiceA' → 'Future<ServiceA>'; 'ServiceB' → 'Future<ServiceB>'."),
      );
    });

    // N sync getters on the same async root → one aggregated diagnostic
    test('emits one aggregated diagnostic when sync getters share the same async root', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        @inject
        class ServiceA {
          ServiceA(this.db);
          final Database db;
        }

        @inject
        class ServiceB {
          ServiceB(this.db);
          final Database db;
        }

        @inject
        class ServiceC {
          ServiceC(this.db);
          final Database db;
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          ServiceA get serviceA;
          ServiceB get serviceB;
          ServiceC get serviceC;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final serviceAClass = library.getClass('ServiceA')!;
      final serviceAData = reader.readInjectable(serviceAClass)!;
      final serviceBClass = library.getClass('ServiceB')!;
      final serviceBData = reader.readInjectable(serviceBClass)!;
      final serviceCClass = library.getClass('ServiceC')!;
      final serviceCData = reader.readInjectable(serviceCClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [
          (classElement: serviceAClass, injectable: serviceAData),
          (classElement: serviceBClass, injectable: serviceBData),
          (classElement: serviceCClass, injectable: serviceCData),
        ],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.hasErrors, isTrue);
      expect(reporter.errorCount, equals(1));
      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          'Component entry points [serviceA, serviceB, serviceC] are declared synchronous but their dependency chain is asynchronous.'
          " The async provider 'DbModule.provideDatabase' in the dependency chain"
          ' causes transitive async propagation.',
        ),
      );
      expect(
        msg.suggestion,
        equals(
          "Change return types: 'ServiceA' → 'Future<ServiceA>';"
          " 'ServiceB' → 'Future<ServiceB>';"
          " 'ServiceC' → 'Future<ServiceC>'.",
        ),
      );
    });

    // Mixed isDirectlyAsync within a group: one entry is the async binding
    // itself (direct), the other depends on it (transitive). The aggregated
    // wording must describe the transitive case so it's accurate for both.
    test('aggregated diagnostic uses transitive wording when group mixes direct and transitive entries', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class DbModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());
        }

        @inject
        class Service {
          Service(this.db);
          final Database db;
        }

        class Database {}

        @Component([DbModule])
        abstract class AppComponent {
          Database get database;
          Service get service;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('DbModule')!;
      final moduleData = reader.readModule(moduleClass);
      final serviceClass = library.getClass('Service')!;
      final serviceData = reader.readInjectable(serviceClass)!;
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [(classElement: serviceClass, injectable: serviceData)],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      expect(reporter.errorCount, equals(1));
      final msg = reporter.messages.single;
      expect(
        msg.message,
        equals(
          'Component entry points [database, service] are declared synchronous but their dependency chain is asynchronous.'
          " The async provider 'DbModule.provideDatabase' in the dependency chain"
          ' causes transitive async propagation.',
        ),
      );
    });

    // Suggestion must remain valid Dart for qualified bindings
    test('suggestion omits qualifier suffix for qualified entry-points', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        const brandName = Qualifier(#brandName);

        @module
        class AppModule {
          @provides
          @asynchronous
          Future<Database> provideDatabase() => Future.value(Database());

          @provides
          @brandName
          Repository provideRepo(Database db) => Repository(db);
        }

        class Database {}

        class Repository {
          Repository(this.db);
          final Database db;
        }

        @Component([AppModule])
        abstract class AppComponent {
          @inject
          @brandName
          Repository get brandedRepo;
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('AppModule')!;
      final moduleData = reader.readModule(moduleClass);
      final componentClass = library.getClass('AppComponent')!;
      final componentData = reader.readComponent(componentClass)!;

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
        entryPoints: componentData.entryPoints,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(asyncResult, componentData.entryPoints);

      final msg = reporter.messages.single;
      expect(
        msg.suggestion,
        equals("Change the getter return type from 'Repository' to 'Future<Repository>'."),
        reason: 'Qualifier suffix must not leak into user-facing suggestion',
      );
    });

    group('a Foo? getter over an exact Foo? binding', () {
      Future<void> validateProviders(String providers) async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Foo {}

          @module
          class AppModule {
            $providers
          }

          @Component([AppModule])
          abstract class AppComponent {
            Foo? get foo;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final moduleClass = library.getClass('AppModule')!;
        final moduleData = reader.readModule(moduleClass);
        final componentData = reader.readComponent(library.getClass('AppComponent')!)!;

        final graphResult = resolver.resolve(
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
          nullableDuplicatePolicy: NullableDuplicatePolicy.allow,
        );
        validator.validate(propagator.propagate(graphResult), componentData.entryPoints);
      }

      test('reports the sync-getter error when the Foo? binding is async', () async {
        await validateProviders('''
          @provides
          @asynchronous
          Future<Foo?> provideOptionalFoo() async => null;
        ''');

        expect(reporter.messages.single.message, contains("Component getter 'foo' is declared synchronous"));
      });

      test('reports nothing when the Foo? binding is sync, even beside an async Foo', () async {
        await validateProviders('''
          @provides
          Foo? provideOptionalFoo() => null;

          @provides
          @asynchronous
          Future<Foo> provideFoo() async => Foo();
        ''');

        expect(reporter.hasErrors, isFalse);
      });
    });

    // Story 8.1 (subcomponents): the same sync-entry-point-on-async-chain
    // rules apply unchanged when the chain crosses a component/subcomponent
    // boundary, or when the async provider is the subcomponent's *own*
    // module rather than the parent's — no special-casing (Architecture
    // Decision 2 in the story's Dev Agent Record).
    group('across a component/subcomponent boundary', () {
      test('reports error for sync subcomponent getter whose chain reaches an async parent binding', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class ParentModule {
            @provides
            @asynchronous
            Future<int> provideAsyncInt() => Future.value(42);
          }

          @module
          class ChildModule {
            @provides
            String provideString(int value) => value.toString();
          }

          @Subcomponent([ChildModule])
          abstract class ChildSubcomponent {
            String get value;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final parentModuleClass = library.getClass('ParentModule')!;
        final childModuleClass = library.getClass('ChildModule')!;
        final parentModuleData = reader.readModule(parentModuleClass);
        final childModuleData = reader.readModule(childModuleClass);
        final subcomponentClass = library.getClass('ChildSubcomponent')!;
        final subcomponentData = reader.readSubcomponent(subcomponentClass)!;

        final parentGraphResult = resolver.resolve(
          modules: [(moduleClass: parentModuleClass, moduleData: parentModuleData)],
          injectables: [],
        );

        final childResolver = BindingResolver(reporter: reporter);
        final childGraphResult = childResolver.resolve(
          modules: [(moduleClass: childModuleClass, moduleData: childModuleData)],
          injectables: [],
          entryPoints: subcomponentData.entryPoints,
          parentBindings: ParentBindings(parentGraphResult.bindingMap),
        );

        final mergedGraphResult = BindingGraphResult(
          bindingMap: {...parentGraphResult.bindingMap, ...childGraphResult.bindingMap},
          dependencyEdges: {...parentGraphResult.dependencyEdges, ...childGraphResult.dependencyEdges},
          duplicateBindings: childGraphResult.duplicateBindings,
          parentBindingsUsed: childGraphResult.parentBindingsUsed,
        );
        final asyncResult = propagator.propagate(mergedGraphResult);
        validator.validate(asyncResult, subcomponentData.entryPoints);

        expect(reporter.hasErrors, isTrue, reason: 'the async root lives in the parent, not the subcomponent');
        final msg = reporter.messages.single;
        expect(
          msg.message,
          equals(
            "Component getter 'value' is declared synchronous but its dependency chain is asynchronous."
            " The async provider 'ParentModule.provideAsyncInt' in the dependency chain"
            ' causes transitive async propagation.',
          ),
        );
      });

      test(
        'allows Future<T> subcomponent getter whose chain reaches the subcomponent\'s own async '
        'module, with a fully synchronous parent',
        () async {
          final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class ParentModule {
            @provides
            int provideInt() => 42;
          }

          @module
          class ChildModule {
            @provides
            @asynchronous
            Future<String> provideAsyncString(int value) => Future.value(value.toString());
          }

          @Subcomponent([ChildModule])
          abstract class ChildSubcomponent {
            Future<String> get value;
          }
        ''');

          final reader = AnnotationReader(reporter: reporter);
          final parentModuleClass = library.getClass('ParentModule')!;
          final childModuleClass = library.getClass('ChildModule')!;
          final parentModuleData = reader.readModule(parentModuleClass);
          final childModuleData = reader.readModule(childModuleClass);
          final subcomponentClass = library.getClass('ChildSubcomponent')!;
          final subcomponentData = reader.readSubcomponent(subcomponentClass)!;

          final parentGraphResult = resolver.resolve(
            modules: [(moduleClass: parentModuleClass, moduleData: parentModuleData)],
            injectables: [],
          );

          final childResolver = BindingResolver(reporter: reporter);
          final childGraphResult = childResolver.resolve(
            modules: [(moduleClass: childModuleClass, moduleData: childModuleData)],
            injectables: [],
            entryPoints: subcomponentData.entryPoints,
            parentBindings: ParentBindings(parentGraphResult.bindingMap),
          );

          final mergedGraphResult = BindingGraphResult(
            bindingMap: {...parentGraphResult.bindingMap, ...childGraphResult.bindingMap},
            dependencyEdges: {...parentGraphResult.dependencyEdges, ...childGraphResult.dependencyEdges},
            duplicateBindings: childGraphResult.duplicateBindings,
            parentBindingsUsed: childGraphResult.parentBindingsUsed,
          );
          final asyncResult = propagator.propagate(mergedGraphResult);
          validator.validate(asyncResult, subcomponentData.entryPoints);

          expect(
            reporter.hasErrors,
            isFalse,
            reason: 'the subcomponent declared its own async boundary correctly with Future<T>',
          );
        },
      );
    });
  });
}
