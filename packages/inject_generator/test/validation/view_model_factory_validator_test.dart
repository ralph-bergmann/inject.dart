import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/dependency_discovery.dart';
import 'package:inject_generator/src/extensions/dart_type_extensions.dart';
import 'package:inject_generator/src/extensions/element_extensions.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/async_propagator.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:inject_generator/src/validation/view_model_factory_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

Future<LibraryElement> _resolveLibrarySources(Map<String, String> sources, {required String resolverFor}) =>
    resolveSources(
      sources,
      (resolver) async => resolver.libraryFor(AssetId.parse(resolverFor)),
      resolverFor: resolverFor,
      readAllSourcesFromFilesystem: true,
    );

void main() {
  late DiagnosticReporter reporter;
  late BindingResolver resolver;
  final propagator = AsyncPropagator();
  late ViewModelFactoryValidator validator;

  setUp(() {
    reporter = DiagnosticReporter();
    resolver = BindingResolver(reporter: reporter);
    validator = ViewModelFactoryValidator(reporter: reporter);
  });

  group('ViewModelFactoryValidator', () {
    test('rejects singleton ViewModel for ViewModelFactory', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class TestBuilder<T> {
          TestBuilder(Provider<T> vmProvider);
        }

        typedef TestViewModelFactory<T> = TestBuilder<T> Function();

        @inject
        @singleton
        class MyViewModel {
          MyViewModel();
        }

        class MyPage {
          @assistedInject
          MyPage(TestViewModelFactory<MyViewModel> factory, @assisted String title);
        }

        @assistedFactory
        abstract class MyPageFactory {
          MyPage create(String title);
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final viewModelClass = library.getClass('MyViewModel')!;
      final viewModelData = reader.readInjectable(viewModelClass)!;
      final factoryClass = library.getClass('MyPageFactory')!;
      final injectClass = library.getClass('MyPage')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final injectables = [(classElement: viewModelClass, injectable: viewModelData)];
      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: injectables,
        modules: [],
        typedefProviders: typedefProviders,
      );

      final graphResult = resolver.resolve(
        modules: [],
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(
        graphResult: graphResult,
        asyncResult: asyncResult,
        modules: [],
        injectables: injectables,
        typedefProviders: typedefProviders,
        factories: factories,
        isViewModelFactory: (type) => type.alias?.element.name == 'TestViewModelFactory',
      );

      expect(reporter.hasErrors, isTrue);
      expect(reporter.messages.any((m) => m.message.contains('cannot use a @singleton ViewModel')), isTrue);
    });

    test('rejects async ViewModel for ViewModelFactory', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class TestBuilder<T> {
          TestBuilder(Provider<T> vmProvider);
        }

        typedef TestViewModelFactory<T> = TestBuilder<T> Function();

        @module
        class AppModule {
          @provides
          @asynchronous
          MyViewModel provideViewModel() => MyViewModel();
        }

        class MyViewModel {
          MyViewModel();
        }

        class MyPage {
          @assistedInject
          MyPage(TestViewModelFactory<MyViewModel> factory, @assisted String title);
        }

        @assistedFactory
        abstract class MyPageFactory {
          MyPage create(String title);
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('AppModule')!;
      final moduleData = reader.readModule(moduleClass);
      final factoryClass = library.getClass('MyPageFactory')!;
      final injectClass = library.getClass('MyPage')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final modules = [(moduleClass: moduleClass, moduleData: moduleData)];
      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: [],
        modules: modules,
        typedefProviders: typedefProviders,
      );

      final graphResult = resolver.resolve(
        modules: modules,
        injectables: [],
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(
        graphResult: graphResult,
        asyncResult: asyncResult,
        modules: modules,
        injectables: [],
        typedefProviders: typedefProviders,
        factories: factories,
        isViewModelFactory: (type) => type.alias?.element.name == 'TestViewModelFactory',
      );

      expect(reporter.hasErrors, isTrue);
      expect(reporter.messages.any((m) => m.message.contains('cannot use an asynchronous ViewModel')), isTrue);
    });

    test('rejects transitively async ViewModel for ViewModelFactory', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class TestBuilder<T> {
          TestBuilder(Provider<T> vmProvider);
        }

        typedef TestViewModelFactory<T> = TestBuilder<T> Function();

        @module
        class AppModule {
          @provides
          @asynchronous
          int provideAsyncInt() => 42;

          @provides
          MyViewModel provideViewModel(int value) => MyViewModel(value);
        }

        class MyViewModel {
          MyViewModel(int value);
        }

        class MyPage {
          @assistedInject
          MyPage(TestViewModelFactory<MyViewModel> factory, @assisted String title);
        }

        @assistedFactory
        abstract class MyPageFactory {
          MyPage create(String title);
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('AppModule')!;
      final moduleData = reader.readModule(moduleClass);
      final factoryClass = library.getClass('MyPageFactory')!;
      final injectClass = library.getClass('MyPage')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final modules = [(moduleClass: moduleClass, moduleData: moduleData)];
      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: [],
        modules: modules,
        typedefProviders: typedefProviders,
      );

      final graphResult = resolver.resolve(
        modules: modules,
        injectables: [],
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(
        graphResult: graphResult,
        asyncResult: asyncResult,
        modules: modules,
        injectables: [],
        typedefProviders: typedefProviders,
        factories: factories,
        isViewModelFactory: (type) => type.alias?.element.name == 'TestViewModelFactory',
      );

      expect(reporter.hasErrors, isTrue);
      expect(reporter.messages.any((m) => m.message.contains('cannot use an asynchronous ViewModel')), isTrue);
      // Transitive async message names the root async provider
      expect(reporter.messages.any((m) => m.message.contains('AppModule.provideAsyncInt')), isTrue);
    });

    test('allows valid non-singleton sync ViewModel for ViewModelFactory', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class TestBuilder<T> {
          TestBuilder(Provider<T> vmProvider);
        }

        typedef TestViewModelFactory<T> = TestBuilder<T> Function();

        @inject
        class MyViewModel {
          MyViewModel();
        }

        class MyPage {
          @assistedInject
          MyPage(TestViewModelFactory<MyViewModel> factory, @assisted String title);
        }

        @assistedFactory
        abstract class MyPageFactory {
          MyPage create(String title);
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final viewModelClass = library.getClass('MyViewModel')!;
      final viewModelData = reader.readInjectable(viewModelClass)!;
      final factoryClass = library.getClass('MyPageFactory')!;
      final injectClass = library.getClass('MyPage')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final injectables = [(classElement: viewModelClass, injectable: viewModelData)];
      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: injectables,
        modules: [],
        typedefProviders: typedefProviders,
      );

      final graphResult = resolver.resolve(
        modules: [],
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(
        graphResult: graphResult,
        asyncResult: asyncResult,
        modules: [],
        injectables: injectables,
        typedefProviders: typedefProviders,
        factories: factories,
        isViewModelFactory: (type) => type.alias?.element.name == 'TestViewModelFactory',
      );

      expect(reporter.hasErrors, isFalse);
    });

    test('rejects singleton ViewModel via production ViewModelFactory detection', () async {
      final library = await _resolveLibrarySources(
        {
          'inject_flutter|lib/src/view_model_factory.dart': '''
            import 'package:inject_annotation/inject_annotation.dart';

            class TestBuilder<T> {
              TestBuilder(Provider<T> vmProvider);
            }

            typedef ViewModelFactory<T> = TestBuilder<T> Function();
          ''',
          '_resolve_source|lib/_resolve_source.dart': '''
            import 'package:inject_annotation/inject_annotation.dart';
            import 'package:inject_flutter/src/view_model_factory.dart';

            @inject
            @singleton
            class MyViewModel {
              MyViewModel();
            }

            class MyPage {
              @assistedInject
              MyPage(ViewModelFactory<MyViewModel> factory, @assisted String title);
            }

            @assistedFactory
            abstract class MyPageFactory {
              MyPage create(String title);
            }
          ''',
        },
        resolverFor: '_resolve_source|lib/_resolve_source.dart',
      );

      final reader = AnnotationReader(reporter: reporter);
      final viewModelClass = library.getClass('MyViewModel')!;
      final viewModelData = reader.readInjectable(viewModelClass)!;
      final factoryClass = library.getClass('MyPageFactory')!;
      final injectClass = library.getClass('MyPage')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final injectables = [(classElement: viewModelClass, injectable: viewModelData)];
      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: injectables,
        modules: [],
        typedefProviders: typedefProviders,
      );

      final graphResult = resolver.resolve(
        modules: [],
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(
        graphResult: graphResult,
        asyncResult: asyncResult,
        modules: [],
        injectables: injectables,
        typedefProviders: typedefProviders,
        factories: factories,
      );

      expect(typedefProviders, isNotEmpty);
      expect(typedefProviders.first.typedefType.isViewModelFactory, isTrue);
      expect(reporter.hasErrors, isTrue);
      expect(reporter.messages.any((m) => m.message.contains('cannot use a @singleton ViewModel')), isTrue);
    });

    test('ignores non-ViewModelFactory typedef providers', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Wrapper<T> {
          Wrapper(Provider<T> provider);
        }

        typedef RegularFactory<T> = Wrapper<T> Function();

        @inject
        @singleton
        class MyService {
          MyService();
        }

        class MyWidget {
          @assistedInject
          MyWidget(RegularFactory<MyService> factory, @assisted String label);
        }

        @assistedFactory
        abstract class MyWidgetFactory {
          MyWidget create(String label);
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final serviceClass = library.getClass('MyService')!;
      final serviceData = reader.readInjectable(serviceClass)!;
      final factoryClass = library.getClass('MyWidgetFactory')!;
      final injectClass = library.getClass('MyWidget')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final injectables = [(classElement: serviceClass, injectable: serviceData)];
      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: injectables,
        modules: [],
        typedefProviders: typedefProviders,
      );

      final graphResult = resolver.resolve(
        modules: [],
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(
        graphResult: graphResult,
        asyncResult: asyncResult,
        modules: [],
        injectables: injectables,
        typedefProviders: typedefProviders,
        factories: factories,
        isViewModelFactory: (type) => type.alias?.element.name == 'TestViewModelFactory',
      );

      // Singleton is fine because it's not going through ViewModelFactory
      expect(reporter.hasErrors, isFalse);
    });

    test('isViewModelFactory returns false for non-inject_flutter typedef', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class TestBuilder<T> {
          TestBuilder(Provider<T> vmProvider);
        }

        typedef TestViewModelFactory<T> = TestBuilder<T> Function();

        class MyViewModel {
          MyViewModel();
        }

        class MyPage {
          @assistedInject
          MyPage(TestViewModelFactory<MyViewModel> factory, @assisted String title);
        }

        @assistedFactory
        abstract class MyPageFactory {
          MyPage create(String title);
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final factoryClass = library.getClass('MyPageFactory')!;
      final injectClass = library.getClass('MyPage')!;
      final factoryData = reader.readAssistedFactory(factoryClass)!;
      final injectData = reader.readAssistedInject(injectClass)!;

      final factories = [(factoryElement: factoryClass, injectData: injectData, factoryData: factoryData)];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: [],
        modules: [],
        typedefProviders: typedefProviders,
      );

      // Verify the production isViewModelFactory returns false for
      // a typedef that is not from inject_flutter.
      expect(typedefProviders, isNotEmpty);
      expect(typedefProviders.first.typedefType.isViewModelFactory, isFalse);
    });

    test('reports distinct diagnostic for each factory that injects a violating typedef', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class TestBuilder<T> {
          TestBuilder(Provider<T> vmProvider);
        }
        typedef TestViewModelFactory<T> = TestBuilder<T> Function();

        @inject
        @singleton
        class MyViewModel {
          MyViewModel();
        }

        class PageA {
          @assistedInject
          PageA(TestViewModelFactory<MyViewModel> factory, @assisted String title);
        }

        @assistedFactory
        abstract class IPageAFactory {
          PageA create(String title);
        }

        class PageB {
          @assistedInject
          PageB(TestViewModelFactory<MyViewModel> factory, @assisted int id);
        }

        @assistedFactory
        abstract class IPageBFactory {
          PageB create(int id);
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final vmClass = library.getClass('MyViewModel')!;
      final vmData = reader.readInjectable(vmClass)!;
      final pageAFactoryClass = library.getClass('IPageAFactory')!;
      final pageAInjectClass = library.getClass('PageA')!;
      final pageAFactoryData = reader.readAssistedFactory(pageAFactoryClass)!;
      final pageAInjectData = reader.readAssistedInject(pageAInjectClass)!;
      final pageBFactoryClass = library.getClass('IPageBFactory')!;
      final pageBInjectClass = library.getClass('PageB')!;
      final pageBFactoryData = reader.readAssistedFactory(pageBFactoryClass)!;
      final pageBInjectData = reader.readAssistedInject(pageBInjectClass)!;

      final injectables = [(classElement: vmClass, injectable: vmData)];
      final factories = [
        (factoryElement: pageAFactoryClass, injectData: pageAInjectData, factoryData: pageAFactoryData),
        (factoryElement: pageBFactoryClass, injectData: pageBInjectData, factoryData: pageBFactoryData),
      ];
      final typedefProviders = <TypedefProviderData>[];

      discoverTypedefProviders(
        reader: reader,
        factories: factories,
        injectables: injectables,
        modules: [],
        typedefProviders: typedefProviders,
      );

      final graphResult = resolver.resolve(
        modules: [],
        injectables: injectables,
        factories: factories,
        typedefProviders: typedefProviders,
      );
      final asyncResult = propagator.propagate(graphResult);
      validator.validate(
        graphResult: graphResult,
        asyncResult: asyncResult,
        modules: [],
        injectables: injectables,
        typedefProviders: typedefProviders,
        factories: factories,
        isViewModelFactory: (type) => type.alias?.element.name == 'TestViewModelFactory',
      );

      expect(reporter.hasErrors, isTrue);
      final singletonMessages = reporter.messages
          .where((m) => m.message.contains('cannot use a @singleton ViewModel'))
          .toList();
      expect(
        singletonMessages,
        hasLength(2),
        reason: 'each factory that injects a violating typedef must receive its own diagnostic',
      );

      // each diagnostic must be anchored to its respective factory
      // element — never to the internal typedef constructor.
      final (String pageAPath, int pageALine, int pageACol) = pageAFactoryClass.elementPosition;
      final (String pageBPath, int pageBLine, int pageBCol) = pageBFactoryClass.elementPosition;
      final Set<(String, int, int)> messageAnchors = singletonMessages
          .map((m) => (m.filePath, m.line, m.column))
          .toSet();
      expect(
        messageAnchors,
        equals({(pageAPath, pageALine, pageACol), (pageBPath, pageBLine, pageBCol)}),
        reason: 'diagnostics must anchor on each factoryElement, not on typedefData.constructor',
      );
    });
  });
}
