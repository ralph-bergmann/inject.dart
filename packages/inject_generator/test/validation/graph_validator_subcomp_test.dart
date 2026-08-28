import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/assisted_reader.dart';
import 'package:inject_generator/src/analysis/component_reader.dart';
import 'package:inject_generator/src/analysis/dependency_discovery.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:inject_generator/src/validation/graph_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

/// Runs the full analysis + validation pipeline for [componentName],
/// mirroring the `InjectBuilder` sequence including subcomponent discovery.
GraphValidator _validateComponent({
  required LibraryElement library,
  required String componentName,
  required DiagnosticReporter reporter,
}) {
  final reader = AnnotationReader(reporter: reporter);
  final validator = GraphValidator(reporter: reporter);

  final ClassElement componentClass = library.getClass(componentName)!;
  final ComponentData componentData = reader.readComponent(componentClass)!;

  final modules = <({ClassElement moduleClass, ModuleData moduleData})>[];
  for (final DartType moduleType in componentData.modules) {
    if (moduleType case InterfaceType(element: final ClassElement classElement)) {
      modules.add((moduleClass: classElement, moduleData: reader.readModule(classElement)));
    }
  }

  final injectables = <({ClassElement classElement, InjectableData injectable})>[];
  final factories = <({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>[];
  discoverAssistedFactories(
    reader: reader,
    componentData: componentData,
    modules: modules,
    injectables: injectables,
    factories: factories,
  );
  discoverInjectables(
    reader: reader,
    componentData: componentData,
    modules: modules,
    injectables: injectables,
    factories: factories,
  );
  final typedefProviders = <TypedefProviderData>[];
  discoverTypedefProviders(
    reader: reader,
    factories: factories,
    injectables: injectables,
    modules: modules,
    typedefProviders: typedefProviders,
  );

  final Set<BindingKey> parentProvidedKeys = collectAllProvidedKeys(
    modules: modules,
    injectables: injectables,
    factories: factories,
    typedefProviders: typedefProviders,
  );
  final List<SubcomponentFactoryDescriptor> descriptors = discoverSubcomponentFactories(
    reader: reader,
    reporter: reporter,
    modules: modules,
    parentProvidedKeys: parentProvidedKeys,
  );

  validator.validate(
    sourceLibrary: library,
    componentClass: componentClass,
    componentData: componentData,
    modules: modules,
    injectables: injectables,
    factories: factories,
    typedefProviders: typedefProviders,
    subcomponentDescriptors: descriptors,
  );

  return validator;
}

void main() {
  late DiagnosticReporter reporter;

  setUp(() {
    reporter = DiagnosticReporter();
  });

  group('GraphValidator with subcomponents', () {
    test('happy path: encapsulated child graph with parent dependency validates cleanly', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Database {
          @inject
          @singleton
          const Database();
        }

        class HttpClient {
          const HttpClient();
        }

        class RestApiService {
          const RestApiService(this.client, this.db);
          final HttpClient client;
          final Database db;
        }

        @module
        class HttpModule {
          @provides
          @singleton
          HttpClient provideClient() => const HttpClient();

          @provides
          RestApiService provideApi(HttpClient client, Database db) => RestApiService(client, db);
        }

        @Subcomponent([HttpModule])
        abstract class HttpSubcomponent {
          RestApiService get apiService;
        }

        abstract class HttpSubcomponentFactory {
          HttpSubcomponent create({HttpModule? httpModule});
        }

        @Module(subcomponents: [HttpSubcomponent])
        class NetworkModule {}

        @Component([NetworkModule])
        abstract class AppComponent {
          Database get db;
          HttpSubcomponentFactory get httpFactory;
        }
      ''');

      final GraphValidator validator = _validateComponent(
        library: library,
        componentName: 'AppComponent',
        reporter: reporter,
      );

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
      expect(validator.lastSubcomponentResults, hasLength(1));
      final SubcomponentValidationResult childResult = validator.lastSubcomponentResults.values.single;
      final BindingKey dbKey = BindingKey.fromDartType(library.getClass('Database')!.thisType)!;
      expect(childResult.graphResult.parentBindingsUsed, contains(dbKey));
    });

    test('multi-level hierarchy is rejected', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Inner {
          @inject
          const Inner();
        }

        @subcomponent
        abstract class InnerSubcomponent {
          Inner get inner;
        }

        abstract class InnerSubcomponentFactory {
          InnerSubcomponent create();
        }

        @Module(subcomponents: [InnerSubcomponent])
        class MiddleModule {
          @provides
          String provideName() => 'middle';
        }

        @Subcomponent([MiddleModule])
        abstract class MiddleSubcomponent {
          String get name;
        }

        abstract class MiddleSubcomponentFactory {
          MiddleSubcomponent create({MiddleModule? middleModule});
        }

        @Module(subcomponents: [MiddleSubcomponent])
        class RootModule {
          @provides
          int provideAnswer() => 42;
        }

        @Component([RootModule])
        abstract class AppComponent {
          int get answer;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isTrue);
      expect(
        reporter.messages.any((m) => m.message.contains('multi-level subcomponent hierarchies are not supported')),
        isTrue,
        reason: reporter.messages.map((m) => m.message).join('\n'),
      );
    });

    test(
      'multi-level hierarchy is rejected also when the nested-installing module is reachable '
      'only through includes: of a subcomponent module',
      () async {
        final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Inner {
          @inject
          const Inner();
        }

        @subcomponent
        abstract class InnerSubcomponent {
          Inner get inner;
        }

        abstract class InnerSubcomponentFactory {
          InnerSubcomponent create();
        }

        @Module(subcomponents: [InnerSubcomponent])
        class NestedInstallerModule {
          @provides
          String provideName() => 'middle';
        }

        // The middle subcomponent lists only the umbrella — the module that
        // actually installs the nested subcomponent is reachable solely via
        // includes:. The lock checks descriptor.subcomponentModules, i.e.
        // the EXPANDED list, so it must still fire.
        @Module(includes: [NestedInstallerModule])
        class ChildUmbrellaModule {}

        @Subcomponent([ChildUmbrellaModule])
        abstract class MiddleSubcomponent {
          String get name;
        }

        abstract class MiddleSubcomponentFactory {
          MiddleSubcomponent create();
        }

        @Module(subcomponents: [MiddleSubcomponent])
        class RootModule {
          @provides
          int provideAnswer() => 42;
        }

        @Component([RootModule])
        abstract class AppComponent {
          int get answer;
        }
      ''');

        _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> multiLevelMessages = reporter.messages.where(
          (m) => m.message.contains('multi-level subcomponent hierarchies are not supported'),
        );
        expect(multiLevelMessages, isNotEmpty, reason: reporter.messages.map((m) => m.message).join('\n'));
        expect(
          multiLevelMessages.any((m) => m.message.contains('NestedInstallerModule')),
          isTrue,
          reason:
              'the lock must name the included module through which the nested installation '
              'happens:\n${multiLevelMessages.map((m) => m.message).join('\n')}',
        );
      },
    );

    test('duplicate installation across two modules reports one aggregated error', () async {
      final LibraryElement library = await _resolveLibrary('''
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
        class ModuleA {
          @provides
          String provideA() => 'a';
        }

        @Module(subcomponents: [HttpSubcomponent])
        class ModuleB {
          @provides
          int provideB() => 2;
        }

        @Component([ModuleA, ModuleB])
        abstract class AppComponent {
          String get a;
          int get b;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isTrue);
      final duplicateMessages = reporter.messages.where((m) => m.message.contains('installed more than once'));
      expect(duplicateMessages, hasLength(1), reason: 'one aggregated error, not one per module');
      expect(duplicateMessages.single.message, contains('ModuleA'));
      expect(duplicateMessages.single.message, contains('ModuleB'));
    });

    test('an installed but never-consumed subcomponent factory is reported as unreachable', () async {
      final LibraryElement library = await _resolveLibrary('''
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
        class AppModule {
          @provides
          String provideName() => 'unrelated';
        }

        @Component([AppModule])
        abstract class AppComponent {
          // Neither a module provider nor an entry point consumes
          // HttpSubcomponentFactory — the installed subcomponent is dead
          // weight and should be flagged, exactly like any other unused
          // binding.
          String get name;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
      final unreachable = reporter.messages.where((m) => m.message.contains('never used'));
      expect(unreachable, isNotEmpty, reason: reporter.messages.map((m) => m.message).join('\n'));
      expect(
        unreachable.any((m) => m.message.contains('HttpSubcomponentFactory')),
        isTrue,
        reason:
            'the installed-but-unconsumed subcomponent factory binding must be flagged as '
            'unreachable:\n${unreachable.map((m) => m.message).join('\n')}',
      );
    });

    test('parent injecting a subcomponent-private binding names the subcomponent (encapsulation)', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class HttpClient {
          const HttpClient();
        }

        @module
        class HttpModule {
          @provides
          HttpClient provideClient() => const HttpClient();
        }

        @Subcomponent([HttpModule])
        abstract class HttpSubcomponent {
          HttpClient get client;
        }

        abstract class HttpSubcomponentFactory {
          HttpSubcomponent create({HttpModule? httpModule});
        }

        @Module(subcomponents: [HttpSubcomponent])
        class NetworkModule {
          @provides
          String provideUrl(HttpClient client) => client.toString();
        }

        @Component([NetworkModule])
        abstract class AppComponent {
          String get url;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isTrue);
      final message = reporter.messages.firstWhere((m) => m.message.contains('No binding found'));
      expect(message.message, contains("provided inside subcomponent 'HttpSubcomponent'"));
      expect(message.suggestion, contains('re-export'));
    });

    test('missing binding inside a child graph names the subcomponent being resolved', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Config {
          const Config();
        }

        class ApiService {
          const ApiService(this.config);
          final Config config;
        }

        @module
        class ChildModule {
          @provides
          ApiService provideApi(Config config) => ApiService(config);
        }

        @Subcomponent([ChildModule])
        abstract class HttpSubcomponent {
          ApiService get apiService;
        }

        abstract class HttpSubcomponentFactory {
          HttpSubcomponent create({ChildModule? childModule});
        }

        @Module(subcomponents: [HttpSubcomponent])
        class NetworkModule {}

        @Component([NetworkModule])
        abstract class AppComponent {
          HttpSubcomponentFactory get httpFactory;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isTrue);
      final DiagnosticMessage message = reporter.messages.firstWhere((m) => m.message.contains('No binding found'));
      expect(message.message, contains("'Config'"));
      expect(
        message.message,
        contains("in subcomponent 'HttpSubcomponent'"),
        reason:
            'the missing-binding diagnostic on the child path must say which subcomponent graph '
            'was being resolved:\n${reporter.messages.map((m) => m.message).join('\n')}',
      );
    });

    test('subcomponent re-declaring a parent key is rejected', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Database {
          const Database();
        }

        @module
        class ChildModule {
          @provides
          Database provideDb() => const Database();
        }

        @Subcomponent([ChildModule])
        abstract class DbSubcomponent {
          Database get db;
        }

        abstract class DbSubcomponentFactory {
          DbSubcomponent create({ChildModule? childModule});
        }

        @Module(subcomponents: [DbSubcomponent])
        class AppModule {
          @provides
          Database provideDb() => const Database();
        }

        @Component([AppModule])
        abstract class AppComponent {
          Database get db;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isTrue);
      expect(
        reporter.messages.any((m) => m.message.contains('already provided by the parent')),
        isTrue,
        reason: reporter.messages.map((m) => m.message).join('\n'),
      );
    });

    test('cycle through the factory re-export is reported with the factory in the path', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class ApiService {
          const ApiService(this.url);
          final String url;
        }

        @module
        class ChildModule {
          @provides
          ApiService provideApi(String url) => ApiService(url);
        }

        @Subcomponent([ChildModule])
        abstract class HttpSubcomponent {
          ApiService get apiService;
        }

        abstract class HttpSubcomponentFactory {
          HttpSubcomponent create({ChildModule? childModule});
        }

        @Module(subcomponents: [HttpSubcomponent])
        class AppModule {
          @provides
          String provideUrl(HttpSubcomponentFactory factory) => factory.toString();
        }

        @Component([AppModule])
        abstract class AppComponent {
          String get url;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isTrue);
      final cycleMessages = reporter.messages.where(
        (m) => m.message.toLowerCase().contains('circular dependency'),
      );
      expect(cycleMessages, isNotEmpty, reason: reporter.messages.map((m) => m.message).join('\n'));
      expect(
        cycleMessages.any((m) => m.message.contains('HttpSubcomponentFactory')),
        isTrue,
        reason:
            'the factory node must appear in the reported cycle path:\n'
            '${cycleMessages.map((m) => m.message).join('\n')}',
      );
    });

    test(
      'a parent-only cycle unrelated to any subcomponent is reported once, not once per '
      'installed subcomponent',
      () async {
        final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class A {
          const A(this.b);
          final B b;
        }

        class B {
          const B(this.a);
          final A a;
        }

        @module
        class CyclicModule {
          @provides
          A provideA(B b) => A(b);

          @provides
          B provideB(A a) => B(a);
        }

        class Marker {
          @inject
          const Marker();
        }

        @subcomponent
        abstract class SubOne {
          Marker get marker;
        }

        @subcomponent
        abstract class SubTwo {
          Marker get marker;
        }

        @Module(subcomponents: [SubOne, SubTwo])
        class SubcomponentsModule {}

        @Component([CyclicModule, SubcomponentsModule])
        abstract class AppComponent {
          A get a;
        }
      ''');

        _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

        expect(reporter.hasErrors, isTrue);
        final cycleMessages = reporter.messages.where(
          (m) => m.message.toLowerCase().contains('circular dependency'),
        );
        expect(
          cycleMessages,
          hasLength(1),
          reason:
              'the A ↔ B cycle lives entirely in the parent, unrelated to either installed '
              'subcomponent — it must be reported once, not once per subcomponent '
              '(regression for the validateSubcomponent cycle-check duplication fix):\n'
              '${cycleMessages.map((m) => m.message).join('\n')}',
        );
      },
    );

    test('async parent binding + sync child entry point is rejected (component rules apply)', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Database {
          const Database();
        }

        class ApiService {
          const ApiService(this.db);
          final Database db;
        }

        @module
        class ChildModule {
          @provides
          ApiService provideApi(Database db) => ApiService(db);
        }

        @Subcomponent([ChildModule])
        abstract class HttpSubcomponent {
          ApiService get apiService;
        }

        abstract class HttpSubcomponentFactory {
          HttpSubcomponent create({ChildModule? childModule});
        }

        @Module(subcomponents: [HttpSubcomponent])
        class AppModule {
          @provides
          @asynchronous
          @singleton
          Future<Database> provideDb() async => const Database();
        }

        @Component([AppModule])
        abstract class AppComponent {
          Future<Database> get db;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isTrue);
      expect(
        reporter.messages.any((m) => m.message.contains('apiService') || m.message.contains('ApiService')),
        isTrue,
        reason: reporter.messages.map((m) => m.message).join('\n'),
      );
    });

    test('async parent binding + Future child entry point validates cleanly', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Database {
          const Database();
        }

        class ApiService {
          const ApiService(this.db);
          final Database db;
        }

        @module
        class ChildModule {
          @provides
          ApiService provideApi(Database db) => ApiService(db);
        }

        @Subcomponent([ChildModule])
        abstract class HttpSubcomponent {
          Future<ApiService> get apiService;
        }

        abstract class HttpSubcomponentFactory {
          HttpSubcomponent create({ChildModule? childModule});
        }

        @Module(subcomponents: [HttpSubcomponent])
        class AppModule {
          @provides
          @asynchronous
          @singleton
          Future<Database> provideDb() async => const Database();
        }

        @Component([AppModule])
        abstract class AppComponent {
          Future<Database> get db;
        }
      ''');

      _validateComponent(library: library, componentName: 'AppComponent', reporter: reporter);

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
    });
  });
}
