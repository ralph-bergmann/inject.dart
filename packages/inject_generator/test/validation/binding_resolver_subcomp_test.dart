import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/dependency_discovery.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/analysis/subcomponent_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_graph_result.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

/// Shared fixture: a parent graph providing [Database] and a subcomponent
/// graph whose [ApiService] consumes it.
const String _hierarchyFixture = '''
  import 'package:inject_annotation/inject_annotation.dart';

  class Database {
    @inject
    @singleton
    const Database();
  }

  class HttpClient {
    @inject
    const HttpClient();
  }

  class ApiService {
    @inject
    const ApiService(this.client, this.db);
    final HttpClient client;
    final Database db;
  }

  @subcomponent
  abstract class HttpSubcomponent {
    ApiService get apiService;
  }

  abstract class HttpSubcomponentFactory {
    HttpSubcomponent create();
  }

  @Module(subcomponents: [HttpSubcomponent])
  class NetworkModule {}

  @component
  abstract class AppComponent {
    Database get db;
  }
''';

void main() {
  late DiagnosticReporter reporter;
  late BindingResolver resolver;
  late AnnotationReader reader;

  setUp(() {
    reporter = DiagnosticReporter();
    resolver = BindingResolver(reporter: reporter);
    reader = AnnotationReader(reporter: reporter);
  });

  /// Resolves the parent graph of [_hierarchyFixture] and returns its result
  /// plus the elements needed for child resolution.
  Future<
    ({
      LibraryElement library,
      BindingGraphResult parentResult,
      SubcomponentData subcomponentData,
      List<({ClassElement classElement, InjectableData injectable})> parentInjectables,
    })
  >
  resolveParent() async {
    final LibraryElement library = await _resolveLibrary(_hierarchyFixture);
    final ClassElement dbClass = library.getClass('Database')!;
    final parentInjectables = [
      for (final injectable in reader.readInjectables(dbClass)) (classElement: dbClass, injectable: injectable),
    ];
    final BindingGraphResult parentResult = resolver.resolve(modules: [], injectables: parentInjectables);
    final SubcomponentData subcomponentData = reader.readSubcomponent(library.getClass('HttpSubcomponent')!)!;
    return (
      library: library,
      parentResult: parentResult,
      subcomponentData: subcomponentData,
      parentInjectables: parentInjectables,
    );
  }

  group('BindingResolver with parentBindings', () {
    test('resolves a child dependency through the parent and records it in parentBindingsUsed', () async {
      final fixture = await resolveParent();
      final LibraryElement library = fixture.library;

      final childInjectables = [
        for (final name in ['HttpClient', 'ApiService'])
          for (final injectable in reader.readInjectables(library.getClass(name)!))
            (classElement: library.getClass(name)!, injectable: injectable),
      ];

      final BindingGraphResult childResult = resolver.resolve(
        modules: [],
        injectables: childInjectables,
        entryPoints: fixture.subcomponentData.entryPoints,
        parentBindings: ParentBindings(fixture.parentResult.bindingMap),
      );

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
      final BindingKey dbKey = BindingKey.fromDartType(library.getClass('Database')!.thisType)!;
      expect(childResult.parentBindingsUsed, {dbKey});
      // The child graph itself never registers the parent binding.
      expect(childResult.bindingMap.containsKey(dbKey), isFalse);
    });

    test('resolves child-only dependencies within the child graph', () async {
      final fixture = await resolveParent();
      final LibraryElement library = fixture.library;

      final childInjectables = [
        for (final name in ['HttpClient', 'ApiService'])
          for (final injectable in reader.readInjectables(library.getClass(name)!))
            (classElement: library.getClass(name)!, injectable: injectable),
      ];

      final BindingGraphResult childResult = resolver.resolve(
        modules: [],
        injectables: childInjectables,
        entryPoints: fixture.subcomponentData.entryPoints,
        parentBindings: ParentBindings(fixture.parentResult.bindingMap),
      );

      final BindingKey clientKey = BindingKey.fromDartType(library.getClass('HttpClient')!.thisType)!;
      expect(childResult.bindingMap.containsKey(clientKey), isTrue);
      expect(childResult.parentBindingsUsed.contains(clientKey), isFalse);
    });

    test('reports missing binding when neither child nor parent provides a dependency', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        abstract class Missing {}

        class Consumer {
          @inject
          const Consumer(this.missing);
          final Missing missing;
        }
      ''');

      final ClassElement consumer = library.getClass('Consumer')!;
      final childInjectables = [
        for (final injectable in reader.readInjectables(consumer)) (classElement: consumer, injectable: injectable),
      ];

      resolver.resolve(
        modules: [],
        injectables: childInjectables,
        parentBindings: ParentBindings(const {}),
        subcomponentName: 'HttpSubcomponent',
      );

      expect(reporter.hasErrors, isTrue);
      expect(reporter.messages.any((m) => m.message.contains('Missing')), isTrue);
      final DiagnosticMessage message = reporter.messages.firstWhere((m) => m.message.contains('No binding found'));
      expect(
        message.message,
        contains("in subcomponent 'HttpSubcomponent'"),
        reason: 'a child-graph missing-binding diagnostic must name the subcomponent being resolved',
      );
    });

    test('reports re-bind error when a child injectable re-declares a parent key', () async {
      final fixture = await resolveParent();
      final LibraryElement library = fixture.library;

      // Simulate the child graph declaring Database itself.
      final ClassElement dbClass = library.getClass('Database')!;
      final childInjectables = [
        for (final injectable in reader.readInjectables(dbClass)) (classElement: dbClass, injectable: injectable),
      ];

      resolver.resolve(
        modules: [],
        injectables: childInjectables,
        parentBindings: ParentBindings(fixture.parentResult.bindingMap),
      );

      expect(reporter.hasErrors, isTrue);
      expect(
        reporter.messages.any((m) => m.message.contains('already provided by the parent')),
        isTrue,
        reason: reporter.messages.map((m) => m.message).join('\n'),
      );
    });

    test('aggregates a parent-rebind of the same key from two child modules into one diagnostic', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Database {
          @inject
          @singleton
          const Database();
        }

        @module
        class ChildModuleA {
          @provides
          Database provideDatabaseA() => const Database();
        }

        @module
        class ChildModuleB {
          @provides
          Database provideDatabaseB() => const Database();
        }
      ''');

      final ClassElement dbClass = library.getClass('Database')!;
      final parentInjectables = [
        for (final injectable in reader.readInjectables(dbClass)) (classElement: dbClass, injectable: injectable),
      ];
      final BindingGraphResult parentResult = resolver.resolve(modules: [], injectables: parentInjectables);

      final moduleAClass = library.getClass('ChildModuleA')!;
      final moduleBClass = library.getClass('ChildModuleB')!;
      final childModules = [
        (moduleClass: moduleAClass, moduleData: reader.readModule(moduleAClass)),
        (moduleClass: moduleBClass, moduleData: reader.readModule(moduleBClass)),
      ];

      final childResolver = BindingResolver(reporter: reporter);
      childResolver.resolve(
        modules: childModules,
        injectables: const [],
        parentBindings: ParentBindings(parentResult.bindingMap),
      );

      final List<String> rebindErrors = reporter.messages
          .map((m) => m.message)
          .where((m) => m.contains('already provided by the parent'))
          .toList();
      expect(
        rebindErrors,
        hasLength(1),
        reason:
            'two child modules rebinding the same key must produce one aggregated diagnostic, not '
            'one per offending module:\n${rebindErrors.join('\n')}',
      );
      expect(rebindErrors.single, contains('ChildModuleA.provideDatabaseA'));
      expect(rebindErrors.single, contains('ChildModuleB.provideDatabaseB'));
    });

    // `_discardIfParentRebind` is exercised above for module providers and
    // injectables. It is called from all five `_register*` methods, so the
    // assisted-factory and typedef-provider paths need their own coverage.
    test('reports re-bind error when a child assisted factory re-declares a parent key', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Widget {
          @assistedInject
          Widget(@assisted String label);
        }

        @assistedFactory
        abstract class WidgetFactory {
          Widget create(String label);
        }

        @module
        class ParentModule {
          @provides
          WidgetFactory provideWidgetFactory() => throw UnimplementedError();
        }
      ''');

      final moduleClass = library.getClass('ParentModule')!;
      final moduleData = reader.readModule(moduleClass);
      final BindingGraphResult parentResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
      );

      final factoryClass = library.getClass('WidgetFactory')!;
      final injectClass = library.getClass('Widget')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final childResolver = BindingResolver(reporter: reporter);
      childResolver.resolve(
        modules: [],
        injectables: [],
        factories: [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)],
        parentBindings: ParentBindings(parentResult.bindingMap),
      );

      expect(reporter.hasErrors, isTrue);
      expect(
        reporter.messages.any((m) => m.message.contains('already provided by the parent')),
        isTrue,
        reason: reporter.messages.map((m) => m.message).join('\n'),
      );
    });

    test('reports re-bind error when a child typedef provider re-declares a parent key', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class UnboundService {
          @inject
          const UnboundService();
        }

        class TestBuilder<T> {
          TestBuilder(UnboundService dep);
        }
        typedef TestFactory<T> = TestBuilder<T> Function(T value);

        class MyClass {
          @assistedInject
          MyClass(TestFactory<String> factory, @assisted int id);
        }

        @assistedFactory
        abstract class IMyFactory {
          MyClass create(int id);
        }

        @module
        class ParentModule {
          @provides
          TestFactory<String> provideTestFactory() => throw UnimplementedError();
        }
      ''');

      final moduleClass = library.getClass('ParentModule')!;
      final moduleData = reader.readModule(moduleClass);
      final BindingGraphResult parentResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
      );

      final factoryClass = library.getClass('IMyFactory')!;
      final injectClass = library.getClass('MyClass')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;
      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];
      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: <({ClassElement classElement, InjectableData injectable})>[],
        modules: <({ClassElement moduleClass, ModuleData moduleData})>[],
        typedefProviders: typedefProviders,
      );
      expect(typedefProviders, isNotEmpty, reason: 'fixture must produce at least one typedef provider');

      final childResolver = BindingResolver(reporter: reporter);
      childResolver.resolve(
        modules: [],
        injectables: [],
        factories: factories,
        typedefProviders: typedefProviders,
        parentBindings: ParentBindings(parentResult.bindingMap),
      );

      expect(reporter.hasErrors, isTrue);
      expect(
        reporter.messages.any((m) => m.message.contains('already provided by the parent')),
        isTrue,
        reason: reporter.messages.map((m) => m.message).join('\n'),
      );
    });

    test('widens a nullable child dependency to a non-nullable parent binding', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Logger {
          @inject
          const Logger();
        }

        class Consumer {
          @inject
          const Consumer(this.logger);
          final Logger? logger;
        }
      ''');

      final ClassElement loggerClass = library.getClass('Logger')!;
      final parentInjectables = [
        for (final injectable in reader.readInjectables(loggerClass))
          (classElement: loggerClass, injectable: injectable),
      ];
      final BindingGraphResult parentResult = resolver.resolve(modules: [], injectables: parentInjectables);

      final ClassElement consumer = library.getClass('Consumer')!;
      final childInjectables = [
        for (final injectable in reader.readInjectables(consumer)) (classElement: consumer, injectable: injectable),
      ];

      final BindingGraphResult childResult = resolver.resolve(
        modules: [],
        injectables: childInjectables,
        parentBindings: ParentBindings(parentResult.bindingMap),
      );

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
      final BindingKey loggerKey = BindingKey.fromDartType(loggerClass.thisType)!;
      expect(childResult.parentBindingsUsed, {loggerKey}, reason: 'the effective (widened) parent key is recorded');
    });
  });

  group('BindingResolver subcomponent factory registration (parent side)', () {
    test('registers the factory binding so module providers can inject it', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class ApiService {
          @inject
          const ApiService();
        }

        @subcomponent
        abstract class HttpSubcomponent {
          ApiService get apiService;
        }

        abstract class HttpSubcomponentFactory {
          HttpSubcomponent create();
        }

        @Module(subcomponents: [HttpSubcomponent])
        class NetworkModule {
          @provides
          String provideDescription(HttpSubcomponentFactory factory) => factory.toString();
        }
      ''');

      final ClassElement networkModule = library.getClass('NetworkModule')!;
      final ClassElement factoryClass = library.getClass('HttpSubcomponentFactory')!;
      final BindingKey factoryKey = BindingKey.fromDartType(factoryClass.thisType)!;

      final BindingGraphResult result = resolver.resolve(
        modules: [(moduleClass: networkModule, moduleData: reader.readModule(networkModule))],
        injectables: [],
        subcomponentFactories: [(key: factoryKey, factoryClass: factoryClass)],
      );

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
      expect(result.bindingMap[factoryKey]?.origin, 'HttpSubcomponentFactory (subcomponent factory)');
    });
  });

  group('BindingResolver subcomponentFactory value parameters', () {
    test('registers a value parameter as an instance binding resolvable by a child injectable', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Greeting {
          @inject
          const Greeting(this.name);
          final String name;
        }
      ''');

      final ClassElement greetingClass = library.getClass('Greeting')!;
      final FormalParameterElement nameParam = greetingClass.constructors.first.formalParameters.single;
      final BindingKey stringKey = BindingKey.fromDartType(nameParam.type)!;

      final injectables = [
        for (final injectable in reader.readInjectables(greetingClass))
          (classElement: greetingClass, injectable: injectable),
      ];

      final BindingGraphResult result = resolver.resolve(
        modules: [],
        injectables: injectables,
        subcomponentFactoryValueParameters: [(key: stringKey, parameter: nameParam)],
      );

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
      expect(result.bindingMap[stringKey]?.origin, 'name (subcomponentFactory value parameter)');
      expect(result.dependencyEdges[stringKey], isEmpty);
    });

    test('a value parameter colliding with an existing module binding is recorded as a duplicate', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Greeting {
          @inject
          const Greeting(this.name);
          final String name;
        }

        @module
        class GreetingModule {
          @provides
          String provideName() => 'hi';
        }
      ''');

      final ClassElement greetingClass = library.getClass('Greeting')!;
      final ClassElement moduleClass = library.getClass('GreetingModule')!;
      final FormalParameterElement nameParam = greetingClass.constructors.first.formalParameters.single;
      final BindingKey stringKey = BindingKey.fromDartType(nameParam.type)!;

      final BindingGraphResult result = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: reader.readModule(moduleClass))],
        injectables: [],
        subcomponentFactoryValueParameters: [(key: stringKey, parameter: nameParam)],
      );

      expect(result.duplicateBindings[stringKey], isNotNull);
      expect(result.duplicateBindings[stringKey], hasLength(2));
    });

    test('a value parameter colliding with a parent-provided binding is rejected as a re-bind', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Greeting {
          @inject
          const Greeting(this.name);
          final String name;
        }

        @module
        class GreetingModule {
          @provides
          String provideName() => 'hi';
        }
      ''');

      final ClassElement greetingClass = library.getClass('Greeting')!;
      final ClassElement moduleClass = library.getClass('GreetingModule')!;
      final FormalParameterElement nameParam = greetingClass.constructors.first.formalParameters.single;
      final BindingKey stringKey = BindingKey.fromDartType(nameParam.type)!;

      // The parent graph already provides an unqualified String binding —
      // the child's @subcomponentFactory value parameter of the same
      // (type, qualifier) must not be allowed to shadow it.
      final parentResolver = BindingResolver(reporter: DiagnosticReporter());
      final BindingGraphResult parentResult = parentResolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: reader.readModule(moduleClass))],
        injectables: [],
      );

      resolver.resolve(
        modules: [],
        injectables: const [],
        subcomponentFactoryValueParameters: [(key: stringKey, parameter: nameParam)],
        parentBindings: ParentBindings(parentResult.bindingMap),
      );

      expect(reporter.hasErrors, isTrue);
      expect(
        reporter.messages.any((m) => m.message.contains('already provided by the parent')),
        isTrue,
        reason: reporter.messages.map((m) => m.message).join('\n'),
      );
    });
  });

  group('BindingResolver subcomponent-private hint (AC-9)', () {
    test('missing-binding error names the subcomponent as nearby source with re-export suggestion', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class HttpClient {
          @inject
          const HttpClient();
        }

        @module
        class AppModule {
          @provides
          String provideUrl(HttpClient client) => client.toString();
        }
      ''');

      final ClassElement appModule = library.getClass('AppModule')!;
      final ClassElement clientClass = library.getClass('HttpClient')!;
      final BindingKey clientKey = BindingKey.fromDartType(clientClass.thisType)!;

      resolver.resolve(
        modules: [(moduleClass: appModule, moduleData: reader.readModule(appModule))],
        injectables: [],
        subcomponentProvidedKeyHints: {clientKey: 'HttpSubcomponent'},
      );

      expect(reporter.hasErrors, isTrue);
      final message = reporter.messages.firstWhere((m) => m.message.contains('No binding found'));
      expect(message.message, contains("provided inside subcomponent 'HttpSubcomponent'"));
      expect(message.suggestion, contains('re-export'));
    });
  });
}
