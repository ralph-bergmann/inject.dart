import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/component_reader.dart';
import 'package:inject_generator/src/analysis/dependency_discovery.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late AnnotationReader reader;

  setUp(() {
    reporter = DiagnosticReporter();
    reader = AnnotationReader(reporter: reporter);
  });

  group('discoverSubcomponentFactories', () {
    const fixture = '''
      import 'package:inject_annotation/inject_annotation.dart';

      class Database {
        @inject
        const Database();
      }

      class HttpClient {
        @inject
        @singleton
        const HttpClient();
      }

      class ApiService {
        @inject
        const ApiService(this.client, this.db);
        final HttpClient client;
        final Database db;
      }

      @module
      class HttpModule {
        @provides
        String provideBaseUrl() => 'https://example.com';
      }

      @Subcomponent([HttpModule])
      abstract class HttpSubcomponent {
        ApiService get apiService;
      }

      // Simulates the abstract class emitted by factory_builder into the
      // .factory.dart part file.
      abstract class HttpSubcomponentFactory {
        HttpSubcomponent create({HttpModule? httpModule});
      }

      @Module(subcomponents: [HttpSubcomponent])
      class NetworkModule {}

      @component
      abstract class AppComponent {
        Database get db;
      }
    ''';

    test('produces a descriptor with subcomponent-scoped injectables only', () async {
      final LibraryElement library = await _resolveLibrary(fixture);

      final ClassElement networkModule = library.getClass('NetworkModule')!;
      final ClassElement dbClass = library.getClass('Database')!;
      final modules = [(moduleClass: networkModule, moduleData: reader.readModule(networkModule))];

      // Parent graph provides Database (as if discovered by the parent).
      final BindingKey parentDbKey = BindingKey.fromDartType(dbClass.thisType)!;

      final List<SubcomponentFactoryDescriptor> descriptors = discoverSubcomponentFactories(
        reader: reader,
        reporter: reporter,
        modules: modules,
        parentProvidedKeys: {parentDbKey},
      );

      expect(descriptors, hasLength(1));
      final SubcomponentFactoryDescriptor descriptor = descriptors.single;
      expect(descriptor.subcomponentClass.name, 'HttpSubcomponent');
      expect(descriptor.subcomponentModules.single.moduleClass.name, 'HttpModule');
      // ApiService + HttpClient belong to the child graph; Database is
      // parent-provided and must NOT be re-discovered into the child.
      expect(
        descriptor.subcomponentInjectables.map((i) => i.classElement.name),
        containsAll(['ApiService', 'HttpClient']),
      );
      expect(
        descriptor.subcomponentInjectables.map((i) => i.classElement.name),
        isNot(contains('Database')),
      );
      expect(descriptor.factoryClass.name, 'HttpSubcomponentFactory');
      expect(descriptor.factoryBindingKey.debugLabel, contains('HttpSubcomponentFactory'));
      expect(reporter.hasErrors, isFalse);
    });

    test('deduplicates the same subcomponent installed by two modules', () async {
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
        class ModuleA {}

        @Module(subcomponents: [HttpSubcomponent])
        class ModuleB {}
      ''');

      final ClassElement moduleA = library.getClass('ModuleA')!;
      final ClassElement moduleB = library.getClass('ModuleB')!;
      final modules = [
        (moduleClass: moduleA, moduleData: reader.readModule(moduleA)),
        (moduleClass: moduleB, moduleData: reader.readModule(moduleB)),
      ];

      final List<SubcomponentFactoryDescriptor> descriptors = discoverSubcomponentFactories(
        reader: reader,
        reporter: reporter,
        modules: modules,
        parentProvidedKeys: const {},
      );

      expect(descriptors, hasLength(1), reason: 'duplicate installation is deduplicated in discovery');
    });

    test('reports an error when the factory class is missing from the library', () async {
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

        @Module(subcomponents: [HttpSubcomponent])
        class NetworkModule {}
      ''');

      final ClassElement networkModule = library.getClass('NetworkModule')!;
      final modules = [(moduleClass: networkModule, moduleData: reader.readModule(networkModule))];

      final List<SubcomponentFactoryDescriptor> descriptors = discoverSubcomponentFactories(
        reader: reader,
        reporter: reporter,
        modules: modules,
        parentProvidedKeys: const {},
      );

      expect(descriptors, isEmpty);
      expect(reporter.hasErrors, isTrue);
      expect(reporter.messages.first.message, contains("HttpSubcomponentFactory"));
    });

    test('discovers assisted factories inside the subcomponent graph', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Logger {
          @inject
          const Logger();
        }

        class Session {
          @assistedInject
          const Session(this.logger, @assisted this.userId);
          final Logger logger;
          final String userId;
        }

        @assistedFactory
        abstract class SessionFactory {
          Session create(String userId);
        }

        @subcomponent
        abstract class AuthSubcomponent {
          SessionFactory get sessionFactory;
        }

        abstract class AuthSubcomponentFactory {
          AuthSubcomponent create();
        }

        @Module(subcomponents: [AuthSubcomponent])
        class AuthModule {}
      ''');

      final ClassElement authModule = library.getClass('AuthModule')!;
      final modules = [(moduleClass: authModule, moduleData: reader.readModule(authModule))];

      final List<SubcomponentFactoryDescriptor> descriptors = discoverSubcomponentFactories(
        reader: reader,
        reporter: reporter,
        modules: modules,
        parentProvidedKeys: const {},
      );

      expect(descriptors, hasLength(1));
      expect(descriptors.single.subcomponentFactories, hasLength(1));
      expect(descriptors.single.subcomponentFactories.single.factoryElement.name, 'SessionFactory');
      expect(
        descriptors.single.subcomponentInjectables.map((i) => i.classElement.name),
        contains('Logger'),
      );
    });

    test('an explicit @subcomponentFactory replaces the synthesized factory lookup', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class RestApiService {
          @inject
          const RestApiService(this.userId);
          final String userId;
        }

        @module
        class ApiModule {}

        @Subcomponent([ApiModule])
        abstract class ApiSubcomponent {
          RestApiService get apiService;
        }

        // Deliberately not named `ApiSubcomponentFactory` (the synthesized
        // name) — proves discovery finds it via the @subcomponentFactory
        // annotation, not the name convention.
        @subcomponentFactory
        abstract class ExplicitApiFactory {
          ApiSubcomponent create(String userId);
        }

        @Module(subcomponents: [ApiSubcomponent])
        class NetworkModule {}
      ''');

      final ClassElement networkModule = library.getClass('NetworkModule')!;
      final modules = [(moduleClass: networkModule, moduleData: reader.readModule(networkModule))];

      final List<SubcomponentFactoryDescriptor> descriptors = discoverSubcomponentFactories(
        reader: reader,
        reporter: reporter,
        modules: modules,
        parentProvidedKeys: const {},
      );

      expect(reporter.hasErrors, isFalse, reason: reporter.messages.map((m) => m.message).join('\n'));
      expect(descriptors, hasLength(1));
      final SubcomponentFactoryDescriptor descriptor = descriptors.single;
      expect(descriptor.factoryClass.name, 'ExplicitApiFactory');
      expect(descriptor.explicitFactory, isNotNull);
      expect(descriptor.valueParameters, hasLength(1));
      expect(descriptor.valueParameters.single.parameter.name, 'userId');
    });

    test(
      'a value parameter of an unsupported binding type is reported and dropped from valueParameters',
      () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class ApiModule {}

          @Subcomponent([ApiModule])
          abstract class ApiSubcomponent {
            String get userId;
          }

          @subcomponentFactory
          abstract class ApiSubcomponentFactory {
            // `dynamic` has no InterfaceType and no type alias, so
            // BindingKey.fromDartType cannot build an identity for it.
            ApiSubcomponent create(dynamic userId);
          }

          @Module(subcomponents: [ApiSubcomponent])
          class NetworkModule {}
        ''');

        final ClassElement networkModule = library.getClass('NetworkModule')!;
        final modules = [(moduleClass: networkModule, moduleData: reader.readModule(networkModule))];

        final List<SubcomponentFactoryDescriptor> descriptors = discoverSubcomponentFactories(
          reader: reader,
          reporter: reporter,
          modules: modules,
          parentProvidedKeys: const {},
        );

        expect(
          reporter.messages.map((m) => m.message),
          anyElement(contains('unsupported binding type')),
        );
        expect(descriptors, hasLength(1));
        expect(
          descriptors.single.valueParameters,
          isEmpty,
          reason: 'A value parameter with no derivable BindingKey must not reach codegen',
        );
      },
    );
  });

  group('discoverInjectables', () {
    test('discovers T (not Provider) for Provider<T> entry point', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @inject
        class CoffeeMaker {
          @inject
          CoffeeMaker();
        }

        @component
        abstract class CoffeeShop {
          @inject
          Provider<CoffeeMaker> get coffeeMaker;
        }
      ''');

      final ClassElement componentClass = library.getClass('CoffeeShop')!;
      final ComponentData componentData = reader.readComponent(componentClass)!;
      final injectables = <({ClassElement classElement, InjectableData injectable})>[];

      discoverInjectables(
        reader: reader,
        componentData: componentData,
        modules: [],
        injectables: injectables,
      );

      expect(injectables, hasLength(1));
      expect(injectables.first.classElement.name, 'CoffeeMaker');
    });

    test('discovers T (not Provider) for Provider<Future<T>> entry point', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @inject
        class CoffeeMaker {
          @inject
          CoffeeMaker();
        }

        @component
        abstract class CoffeeShop {
          @inject
          Provider<Future<CoffeeMaker>> get coffeeMaker;
        }
      ''');

      final ClassElement componentClass = library.getClass('CoffeeShop')!;
      final ComponentData componentData = reader.readComponent(componentClass)!;
      final injectables = <({ClassElement classElement, InjectableData injectable})>[];

      discoverInjectables(
        reader: reader,
        componentData: componentData,
        modules: [],
        injectables: injectables,
      );

      expect(injectables, hasLength(1));
      expect(injectables.first.classElement.name, 'CoffeeMaker');
    });

    test('discovers both constructors for multi-constructor class with qualifiers', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        const preview = Qualifier(#preview);
        const detail = Qualifier(#detail);

        class ProfileWidget {
          @inject
          @preview
          ProfileWidget.preview();

          @inject
          @detail
          ProfileWidget.detail();
        }

        @component
        abstract class ProfileComponent {
          @inject
          @preview
          ProfileWidget get previewWidget;

          @inject
          @detail
          ProfileWidget get detailWidget;
        }
      ''');

      final ClassElement componentClass = library.getClass('ProfileComponent')!;
      final ComponentData componentData = reader.readComponent(componentClass)!;
      final injectables = <({ClassElement classElement, InjectableData injectable})>[];

      discoverInjectables(
        reader: reader,
        componentData: componentData,
        modules: [],
        injectables: injectables,
      );

      expect(injectables, hasLength(2));
      expect(injectables[0].classElement.name, 'ProfileWidget');
      expect(injectables[1].classElement.name, 'ProfileWidget');
      expect(injectables[0].injectable.key.qualifier, isNot(injectables[1].injectable.key.qualifier));
    });
  });

  group('collectModuleProvidedKeys', () {
    test('collects distinct BindingKeys for qualified module providers', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        const preview = Qualifier(#preview);
        const detail = Qualifier(#detail);

        class ProfileWidget {}

        @module
        class ProfileModule {
          @provides
          @preview
          ProfileWidget providePreview() => ProfileWidget();

          @provides
          @detail
          ProfileWidget provideDetail() => ProfileWidget();
        }
      ''');

      final ClassElement moduleClass = library.getClass('ProfileModule')!;
      final ModuleData moduleData = reader.readModule(moduleClass);
      final List<({ClassElement moduleClass, ModuleData moduleData})> modules = [
        (moduleClass: moduleClass, moduleData: moduleData),
      ];

      final Set<BindingKey> keys = collectModuleProvidedKeys(modules);

      expect(keys, hasLength(2));
      final Set<String?> qualifiers = keys.map((k) => k.qualifier).toSet();
      expect(qualifiers, contains('preview'));
      expect(qualifiers, contains('detail'));
      // Both keys share the same type identity
      final Set<String> typeIdentities = keys.map((k) => k.typeIdentity).toSet();
      expect(typeIdentities, hasLength(1));
    });

    test('includes both unwrapped and Future key for @asynchronous provider', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class RemoteConfig {}

        @module
        class ConfigModule {
          @provides
          @asynchronous
          Future<RemoteConfig> provideConfig() async => RemoteConfig();
        }
      ''');

      final ClassElement moduleClass = library.getClass('ConfigModule')!;
      final ModuleData moduleData = reader.readModule(moduleClass);
      final List<({ClassElement moduleClass, ModuleData moduleData})> modules = [
        (moduleClass: moduleClass, moduleData: moduleData),
      ];

      final Set<BindingKey> keys = collectModuleProvidedKeys(modules);

      // Should contain both the unwrapped RemoteConfig key and the
      // Future<RemoteConfig> key.
      expect(keys, hasLength(2));
      final Set<String> typeIdentities = keys.map((k) => k.typeIdentity).toSet();
      expect(typeIdentities, hasLength(2));
      expect(typeIdentities.any((id) => id.contains('RemoteConfig') && !id.contains('Future')), isTrue);
      expect(typeIdentities.any((id) => id.contains('Future')), isTrue);
    });
  });
}
