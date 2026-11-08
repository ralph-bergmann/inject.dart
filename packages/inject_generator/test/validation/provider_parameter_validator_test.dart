import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/dependency_discovery.dart';
import 'package:inject_generator/src/extensions/dart_type_extensions.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/async_propagator.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:inject_generator/src/validation/provider_parameter_validator.dart';
import 'package:inject_generator/src/validation/view_model_factory_validator.dart';
import 'package:test/test.dart';

void main() {
  test('skips the Provider<T> parameter of a ViewModelFactory typedef over an async ViewModel', () async {
    const resolverFor = '_resolve_source|lib/_resolve_source.dart';
    final library = await resolveSources(
      {
        'inject_flutter|lib/src/view_model_factory.dart': '''
          import 'package:inject_annotation/inject_annotation.dart';

          class TestBuilder<T> {
            TestBuilder(Provider<T> vmProvider);
          }

          typedef ViewModelFactory<T> = TestBuilder<T> Function();
        ''',
        resolverFor: '''
          import 'package:inject_annotation/inject_annotation.dart';
          import 'package:inject_flutter/src/view_model_factory.dart';

          @module
          class AppModule {
            @provides
            @asynchronous
            Future<MyViewModel> provideViewModel() async => MyViewModel();
          }

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
      (resolver) async => resolver.libraryFor(AssetId.parse(resolverFor)),
      resolverFor: resolverFor,
      readAllSourcesFromFilesystem: true,
    );

    final reporter = DiagnosticReporter();
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

    final graphResult = BindingResolver(
      reporter: reporter,
    ).resolve(modules: modules, injectables: [], factories: factories, typedefProviders: typedefProviders);
    final asyncResult = AsyncPropagator().propagate(graphResult);
    ProviderParameterValidator(reporter: reporter).validate(asyncResult, graphResult.providerParameters);
    ViewModelFactoryValidator(reporter: reporter).validate(
      graphResult: graphResult,
      asyncResult: asyncResult,
      modules: modules,
      injectables: [],
      typedefProviders: typedefProviders,
      factories: factories,
    );

    final typedefProvider = typedefProviders.single;
    expect(typedefProvider.typedefType.isViewModelFactory, isTrue);
    expect(typedefProvider.injectedParams.single.passProvider, isTrue);
    expect(
      graphResult.providerParameters.map((p) => p.parameter.name),
      isNot(contains('vmProvider')),
      reason: 'ViewModelFactoryValidator owns this typedef',
    );
    expect(reporter.messages.single.message, contains('cannot use an asynchronous ViewModel'));
  });
}
