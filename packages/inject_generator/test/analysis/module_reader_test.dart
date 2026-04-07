import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
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
  late ModuleReader moduleReader;

  setUp(() {
    reporter = DiagnosticReporter();
    moduleReader = ModuleReader(reporter: reporter);
  });

  group('ModuleReader', () {
    group('provider extraction', () {
      test('reads single @provides method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            Heater provideHeater() => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.key, isA<BindingKey>());
        expect(result.providers.first.key.qualifier, isNull);
        expect(result.providers.first.key.debugLabel, 'Heater');
        expect(result.providers.first.method.name, 'provideHeater');
        expect(result.providers.first.returnType.element?.name, 'Heater');
        expect(result.providers.first.dependencies, isEmpty);
      });

      test('reads multiple @provides methods in declaration order', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}
          class Pump {}
          class Grinder {}

          @module
          class CoffeeModule {
            @provides
            Heater provideHeater() => Heater();

            @provides
            Pump providePump() => Pump();

            @provides
            Grinder provideGrinder() => Grinder();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(3));
        expect(result.providers[0].method.name, 'provideHeater');
        expect(result.providers[1].method.name, 'providePump');
        expect(result.providers[2].method.name, 'provideGrinder');
      });

      test('reads @provides method with parameters as dependencies', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Electricity {}
          class PowerOutlet {}
          class Heater {}

          @module
          class CoffeeModule {
            @provides
            Heater provideHeater(Electricity e, PowerOutlet o) => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.dependencies, hasLength(2));
        expect(result.providers.first.dependencies[0].type.element?.name, 'Electricity');
        expect(result.providers.first.dependencies[1].type.element?.name, 'PowerOutlet');
      });

      test('ignores non-@provides methods', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            Heater provideHeater() => Heater();

            Heater helperMethod() => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.method.name, 'provideHeater');
      });

      test('reads @module with zero @provides methods', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class EmptyModule {}
        ''');

        final ClassElement classElement = library.getClass('EmptyModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, isEmpty);
      });
    });

    group('binding metadata', () {
      test('reads @singleton on @provides method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            @singleton
            Heater provideHeater() => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers.first.metadata.isSingleton, isTrue);
        expect(result.providers.first.metadata.isAsynchronous, isFalse);
        expect(result.providers.first.metadata.qualifier, isNull);
      });

      test('reads @asynchronous on @provides method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class PowerOutlet {}

          @module
          class CoffeeModule {
            @provides
            @asynchronous
            Future<PowerOutlet> providePowerOutlet() async => PowerOutlet();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers.first.metadata.isAsynchronous, isTrue);
        expect(result.providers.first.metadata.isSingleton, isFalse);
      });

      test('unwraps Future<T> to T for binding key when @asynchronous', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            @asynchronous
            Future<Heater> provideHeater() async => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        final ProviderDescriptor provider = result.providers.first;
        // Key must be derived from T (Heater), not Future<T>
        expect(provider.key.debugLabel, 'Heater');
        // Original return type preserved as Future<Heater> for codegen
        expect(provider.returnType.element?.name, 'Future');
        expect(provider.returnType.toString(), contains('Future<Heater>'));
        expect(provider.metadata.isAsynchronous, isTrue);
      });

      test('does not unwrap Future<T> when @asynchronous is absent', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            Future<Heater> provideHeater() async => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        final ProviderDescriptor provider = result.providers.first;
        // Without @asynchronous, Future<T> is the literal binding type
        expect(provider.key.debugLabel, 'Future<Heater>');
        expect(provider.metadata.isAsynchronous, isFalse);
      });

      test('reads @Qualifier on @provides method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);

          @module
          class CoffeeModule {
            @provides
            @brandName
            String provideBrand() => 'Coffee Inc.';
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers.first.metadata.qualifier, 'brandName');
        expect(result.providers.first.key, isA<BindingKey>());
        expect(result.providers.first.key.qualifier, 'brandName');
        expect(result.providers.first.key.debugLabel, 'String (#brandName)');
      });

      test('reads combined @singleton + @asynchronous + @Qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class ExpensiveService {}

          const primary = Qualifier(#primary);

          @module
          class ServiceModule {
            @provides
            @singleton
            @asynchronous
            @primary
            Future<ExpensiveService> provideService() async => ExpensiveService();
          }
        ''');

        final ClassElement classElement = library.getClass('ServiceModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers.first.metadata.isSingleton, isTrue);
        expect(result.providers.first.metadata.isAsynchronous, isTrue);
        expect(result.providers.first.metadata.qualifier, 'primary');
      });

      test('reads @Qualifier on parameter', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);

          @module
          class CoffeeModule {
            @provides
            String provideLabel(@brandName String brand) => 'Label: \$brand';
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers.first.dependencies, hasLength(1));
        expect(result.providers.first.dependencies.first.qualifier, 'brandName');
      });
    });

    group('provision listener', () {
      test('reads @provisionListener on @provides method', () async {
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
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isTrue);
        expect(result.providers.first.metadata.isSingleton, isTrue);
      });

      test('isProvisionListener is false for regular @provides method', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            Heater provideHeater() => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isFalse);
      });

      test('emits info when @provisionListener without @singleton', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }

          @module
          class AppModule {
            @provides
            @provisionListener
            ProvisionListener<Object> provideListener() => LoggingListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isTrue);
        expect(reporter.messages, hasLength(1));
        expect(reporter.messages.first.severity, DiagnosticSeverity.info);
        expect(reporter.messages.first.message, contains('@provisionListener'));
        expect(reporter.messages.first.message, contains('treated as a singleton automatically'));
      });

      test('emits error when return type does not implement ProvisionListener', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class NotAListener {}

          @module
          class AppModule {
            @provides
            @singleton
            @provisionListener
            NotAListener provideListener() => NotAListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        // Provider is kept as degraded non-listener to avoid cascading errors
        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isFalse);
        expect(reporter.messages, hasLength(1));
        expect(reporter.messages.first.message, contains('does not implement ProvisionListener'));
      });

      test('extracts type argument from ProvisionListener<Heater>', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            @singleton
            @provisionListener
            ProvisionListener<Heater> provideListener() => HeaterListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isTrue);
        expect(result.providers.first.metadata.listenerTypeArgument, isNotNull);
        expect(result.providers.first.metadata.listenerTypeArgument!.element?.name, 'Heater');
      });

      test('listenerTypeArgument is null for ProvisionListener<Object> (catch-all)', () async {
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
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isTrue);
        expect(result.providers.first.metadata.listenerTypeArgument, isNull);
      });

      test('extracts type argument from concrete subclass return type', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          class HeaterListener implements ProvisionListener<Heater> {
            @override
            void onProvision(Heater instance) {}
          }

          @module
          class AppModule {
            @provides
            @singleton
            @provisionListener
            HeaterListener provideListener() => HeaterListener();
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isTrue);
        expect(result.providers.first.metadata.listenerTypeArgument, isNotNull);
        expect(result.providers.first.metadata.listenerTypeArgument!.element?.name, 'Heater');
      });

      test('listenerTypeArgument is null for non-listener provider', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Heater {}

          @module
          class CoffeeModule {
            @provides
            Heater provideHeater() => Heater();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isFalse);
        expect(result.providers.first.metadata.listenerTypeArgument, isNull);
      });

      test('@provisionListener with dependencies is valid', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class Logger {}

          class LoggingListener implements ProvisionListener<Object> {
            LoggingListener(Logger logger);
            @override
            void onProvision(Object instance) {}
          }

          @module
          class AppModule {
            @provides
            @singleton
            @provisionListener
            ProvisionListener<Object> provideListener(Logger logger) => LoggingListener(logger);
          }
        ''');

        final ClassElement classElement = library.getClass('AppModule')!;
        final ModuleData result = moduleReader.readModule(classElement);

        expect(result.providers, hasLength(1));
        expect(result.providers.first.metadata.isProvisionListener, isTrue);
        expect(result.providers.first.dependencies, hasLength(1));
        expect(result.providers.first.dependencies.first.type.element?.name, 'Logger');
      });
    });

    group('hasDefaultConstructor', () {
      test('class M {} — implicit default ctor → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {}
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('class M { M(); } — explicit default ctor → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M();
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('class M { const M(); } — const is orthogonal to callability → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            const M();
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('class M { M([String x = ""]); } — optional positional → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M([String x = "foo"]);
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('class M { M({String? x}); } — named optional → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M({String? x});
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('class M { M(String x); } — required positional → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M(String x);
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M { M({required String x}); } — required named → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M({required String x});
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M { M(String a, [int b = 1]); } — first param required → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M(String a, [int b = 1]);
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M { M._(); } — private ctor → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M._();
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M { factory M() => _MImpl(); } — public factory → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            factory M() => _MImpl();
          }
          class _MImpl implements M {}
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('class M { factory M._() => _MImpl(); } — private factory → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            factory M._() => _MImpl();
          }
          class _MImpl implements M {}
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M { M() : this._inner(); M._inner(); } — redirecting public ctor → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M() : this._inner();
            M._inner();
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('abstract class M {} — abstract cannot be instantiated → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          abstract class M {}
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M { M(); M.named(String x); } — default present → true', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M();
            M.named(String x);
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isTrue);
      });

      test('class M { M.a(); M.b(String x); } — no unnamed ctor → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            M.a();
            M.b(String x);
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M { const M._(); } — private const ctor → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M {
            const M._();
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });

      test('class M<T> { M(); } — generic class → false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';
          @module
          class M<T> {
            M();
          }
        ''');
        final ClassElement classElement = library.getClass('M')!;
        final ModuleData result = moduleReader.readModule(classElement);
        expect(result.hasDefaultConstructor, isFalse);
      });
    });
  });
}
