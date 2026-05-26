import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/codegen/listener_generator.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late ModuleReader moduleReader;

  setUp(() {
    reporter = DiagnosticReporter();
    moduleReader = ModuleReader(reporter: reporter);
  });

  group('ListenerGenerator', () {
    group('matchingListeners', () {
      test('catch-all listener matches all types', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }

          @module
          class AppModule {
            @provides
            Heater provideHeater() => Heater();

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Object> provideListener() => LoggingListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData moduleData = moduleReader.readModule(classElement);
        final ProviderDescriptor heaterProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideHeater',
        );
        final ProviderDescriptor listenerProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideListener',
        );

        final List<ListenerCallInfo> matches = ListenerGenerator.matchingListeners(
          provisionedType: heaterProvider.returnType,
          listenerProviders: [(moduleClass: classElement, descriptor: listenerProvider)],
        );

        expect(matches, hasLength(1));
        expect(matches.first.providerClassName, '_ProvisionListenerOfObject\$Provider');
      });

      test('type-specific listener matches only assignable types', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}
          class Pump {}

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            Heater provideHeater() => Heater();

            @provides
            Pump providePump() => Pump();

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Heater> provideListener() => HeaterListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData moduleData = moduleReader.readModule(classElement);
        final ProviderDescriptor heaterProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideHeater',
        );
        final ProviderDescriptor pumpProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'providePump',
        );
        final ProviderDescriptor listenerProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideListener',
        );

        final List<({ProviderDescriptor descriptor, ClassElement moduleClass})> listenerProviders = [
          (moduleClass: classElement, descriptor: listenerProvider),
        ];

        final List<ListenerCallInfo> heaterMatches = ListenerGenerator.matchingListeners(
          provisionedType: heaterProvider.returnType,
          listenerProviders: listenerProviders,
        );
        expect(heaterMatches, hasLength(1));

        final List<ListenerCallInfo> pumpMatches = ListenerGenerator.matchingListeners(
          provisionedType: pumpProvider.returnType,
          listenerProviders: listenerProviders,
        );
        expect(pumpMatches, isEmpty);
      });

      test('self-key prevents infinite recursion', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }

          @module
          class AppModule {
            @provides
            @singleton
            @provisionListener
            ProvisionListener<Object> provideListener() => LoggingListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData moduleData = moduleReader.readModule(classElement);
        final ProviderDescriptor listenerProvider = moduleData.providers.first;

        final List<ListenerCallInfo> matches = ListenerGenerator.matchingListeners(
          provisionedType: listenerProvider.returnType,
          listenerProviders: [(moduleClass: classElement, descriptor: listenerProvider)],
          selfKey: listenerProvider.key,
        );

        expect(matches, isEmpty, reason: 'Listener should not fire for its own provision');
      });

      test('multiple listeners match the same type', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            Heater provideHeater() => Heater();

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Object> provideCatchAll() => LoggingListener();

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Heater> provideHeaterListener() => HeaterListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData moduleData = moduleReader.readModule(classElement);
        final ProviderDescriptor heaterProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideHeater',
        );
        final ProviderDescriptor catchAllListener = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideCatchAll',
        );
        final ProviderDescriptor heaterListener = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideHeaterListener',
        );

        final List<({ProviderDescriptor descriptor, ClassElement moduleClass})> listenerProviders = [
          (moduleClass: classElement, descriptor: catchAllListener),
          (moduleClass: classElement, descriptor: heaterListener),
        ];

        final List<ListenerCallInfo> matches = ListenerGenerator.matchingListeners(
          provisionedType: heaterProvider.returnType,
          listenerProviders: listenerProviders,
        );

        expect(matches, hasLength(2));
      });

      test('subtype matches type-specific listener', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}
          class ElectricHeater extends Heater {}

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            ElectricHeater provideElectricHeater() => ElectricHeater();

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Heater> provideListener() => HeaterListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData moduleData = moduleReader.readModule(classElement);
        final ProviderDescriptor electricHeaterProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideElectricHeater',
        );
        final ProviderDescriptor listenerProvider = moduleData.providers.firstWhere(
          (p) => p.method.name == 'provideListener',
        );

        final List<ListenerCallInfo> matches = ListenerGenerator.matchingListeners(
          provisionedType: electricHeaterProvider.returnType,
          listenerProviders: [(moduleClass: classElement, descriptor: listenerProvider)],
        );

        expect(matches, hasLength(1), reason: 'ElectricHeater is assignable to Heater');
      });

      test('returns empty list when no listeners provided', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class AppModule {
            @provides
            Heater provideHeater() => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData moduleData = moduleReader.readModule(classElement);
        final ProviderDescriptor heaterProvider = moduleData.providers.first;

        final List<ListenerCallInfo> matches = ListenerGenerator.matchingListeners(
          provisionedType: heaterProvider.returnType,
          listenerProviders: [],
        );

        expect(matches, isEmpty);
      });
    });
  });
}
