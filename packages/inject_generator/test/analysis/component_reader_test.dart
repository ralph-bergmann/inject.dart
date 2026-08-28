import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/component_reader.dart';
import 'package:inject_generator/src/analysis/entry_point_collector.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late ComponentReader componentReader;

  setUp(() {
    reporter = DiagnosticReporter();
    componentReader = ComponentReader(reporter: reporter);
  });

  group('ComponentReader', () {
    group('module extraction', () {
      test('reads @component with zero modules', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @component
          abstract class CoffeeShop {}
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules, isEmpty);
      });

      test('reads @Component with single module', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class DripCoffeeModule {}

          @Component([DripCoffeeModule])
          abstract class CoffeeShop {}
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules, hasLength(1));
        expect(result.modules.first.element?.name, 'DripCoffeeModule');
      });

      test('reports duplicate module in @Component as error', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class M {}

          @Component([M, M])
          abstract class C {}
        ''');

        final ClassElement classElement = library.getClass('C')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules, hasLength(1), reason: 'duplicate must be dropped from modules list');
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('listed more than once'));
      });

      test('reports a @subcomponent-annotated type in the @Component module list as an error', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class NetworkModule {}

          @subcomponent
          abstract class HttpSubcomponent {}

          @Component([NetworkModule, HttpSubcomponent])
          abstract class AppComponent {}
        ''');

        final ClassElement classElement = library.getClass('AppComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(
          result!.modules.map((m) => m.element?.name),
          ['NetworkModule'],
          reason: 'the @subcomponent entry must be dropped from the module list',
        );
        expect(reporter.hasErrors, isTrue);
        final DiagnosticMessage message = reporter.messages.firstWhere((m) => m.message.contains('HttpSubcomponent'));
        expect(message.message, contains('annotated with @subcomponent'));
        expect(message.message, contains("@Component on 'AppComponent'"));
        expect(message.suggestion, contains('@Module(subcomponents: [HttpSubcomponent])'));
      });

      test('reads @Component with multiple modules in declaration order', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class BikeServices {}

          @module
          class FoodServices {}

          @module
          class CommonServices {}

          @Component([BikeServices, FoodServices, CommonServices])
          abstract class TrainServices {}
        ''');

        final ClassElement classElement = library.getClass('TrainServices')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules, hasLength(3));
        expect(result.modules[0].element?.name, 'BikeServices');
        expect(result.modules[1].element?.name, 'FoodServices');
        expect(result.modules[2].element?.name, 'CommonServices');
      });

      test('preserves module declaration order from @Component annotation', () async {
        // Module declaration order is a public contract — later modules override
        // earlier ones. If this list ever becomes a Set or Map<Type,...>,
        // override semantics break silently.
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class ModuleA {}

          @module
          class ModuleB {}

          @Component([ModuleB, ModuleA])
          abstract class AppComponent {}
        ''');

        final ClassElement classElement = library.getClass('AppComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        // ModuleB must be first — any alphabetical sort would flip this to [ModuleA, ModuleB].
        expect(
          result!.modules.map((dt) => dt.element?.name).toList(),
          equals(['ModuleB', 'ModuleA']),
        );
      });
    });

    group('entry point extraction', () {
      test('reads @inject getters as entry points', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            @inject
            CoffeeMaker get coffeeMaker;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final getter = result.entryPoints.first.element as GetterElement;
        expect(getter.returnType.element?.name, 'CoffeeMaker');
      });

      test('reads @inject methods as entry points', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            @inject
            Future<CoffeeMaker> getCoffeeMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final method = result.entryPoints.first.element as MethodElement;
        expect(method.name, 'getCoffeeMaker');
        expect(method.returnType.toString(), contains('Future<CoffeeMaker>'));
      });

      test('unwraps Future<T> entry-point key to T and records isFuture', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            @inject
            Future<CoffeeMaker> getCoffeeMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final EntryPoint ep = result.entryPoints.first;
        // Key derived from T (CoffeeMaker), not Future<T>
        expect(ep.key.debugLabel, 'CoffeeMaker');
        // isFuture flag set
        expect(ep.isFuture, isTrue);
        expect(ep.isProvider, isFalse);
        // Original element preserves Future<T> return type for codegen
        final method = ep.element as MethodElement;
        expect(method.returnType.toString(), contains('Future<CoffeeMaker>'));
      });

      test('non-Future entry-point has isFuture false', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            @inject
            CoffeeMaker get coffeeMaker;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final EntryPoint ep = result.entryPoints.first;
        expect(ep.key.debugLabel, 'CoffeeMaker');
        expect(ep.isFuture, isFalse);
        expect(ep.isProvider, isFalse);
      });

      test('ignores non-abstract unannotated getters and methods', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}
          class TeaMaker {}

          @component
          abstract class CoffeeShop {
            CoffeeMaker get coffeeMaker => CoffeeMaker();
            TeaMaker getTeaMaker() => TeaMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, isEmpty);
      });

      test('treats abstract getters without @inject as entry points', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            CoffeeMaker get coffeeMaker;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final getter = result.entryPoints.first.element as GetterElement;
        expect(getter.returnType.element?.name, 'CoffeeMaker');
      });

      test('treats abstract methods without @inject as entry points', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            Future<CoffeeMaker> getCoffeeMaker();
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final method = result.entryPoints.first.element as MethodElement;
        expect(method.name, 'getCoffeeMaker');
      });

      test('reads qualifier from abstract getter without @inject', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);

          @component
          abstract class CoffeeShop {
            @brandName
            String get brand;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        expect(result.entryPoints.first.key.qualifier, 'brandName');
      });

      test('reads both @inject getters and methods in declaration order', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}
          class TeaMaker {}
          class WaterHeater {}

          @component
          abstract class BeverageShop {
            @inject
            CoffeeMaker get coffeeMaker;

            @inject
            Future<TeaMaker> getTeaMaker();

            @inject
            WaterHeater get waterHeater;
          }
        ''');

        final ClassElement classElement = library.getClass('BeverageShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(3));
        // Preserved in source declaration order (getter, method, getter)
        expect((result.entryPoints[0].element as GetterElement).name, 'coffeeMaker');
        expect((result.entryPoints[1].element as MethodElement).name, 'getTeaMaker');
        expect((result.entryPoints[2].element as GetterElement).name, 'waterHeater');
      });

      test('propagates qualifier to entry-point key', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brandName = Qualifier(#brandName);

          @component
          abstract class CoffeeShop {
            @inject
            @brandName
            String get brand;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        expect(result.entryPoints.first.key.qualifier, 'brandName');
      });

      test('unqualified entry-point key has null qualifier', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            @inject
            CoffeeMaker get coffeeMaker;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        expect(result.entryPoints.first.key.qualifier, isNull);
      });

      test('same type with different qualifiers produces distinct keys', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const host = Qualifier(#host);
          const port = Qualifier(#port);

          @component
          abstract class AppComponent {
            @inject
            @host
            String get serverHost;

            @inject
            @port
            String get serverPort;

            @inject
            String get defaultName;
          }
        ''');

        final ClassElement classElement = library.getClass('AppComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(3));
        final List<String?> qualifiers = result.entryPoints.map((ep) => ep.key.qualifier).toList();
        expect(qualifiers, contains('host'));
        expect(qualifiers, contains('port'));
        expect(qualifiers, contains(isNull));
      });

      test('reports unsupported function return type instead of silently dropping entry point', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @component
          abstract class CoffeeShop {
            @inject
            void Function() get onReady;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, isEmpty);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.any((m) => m.message.contains('Function type')), isTrue);
        expect(reporter.messages.any((m) => m.message.contains('component entry point')), isTrue);
      });

      test('preserves same-name entry points with different qualifiers from interfaces', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brand = Qualifier(#brand);
          const model = Qualifier(#model);

          abstract class BrandProvider {
            @inject
            @brand
            String get label;
          }

          abstract class ModelProvider {
            @inject
            @model
            String get label;
          }

          @component
          abstract class CarComponent implements BrandProvider, ModelProvider {}
        ''');

        final ClassElement classElement = library.getClass('CarComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(2));
        final Set<String?> qualifiers = result.entryPoints.map((ep) => ep.key.qualifier).toSet();
        expect(qualifiers, containsAll(['brand', 'model']));
      });

      test('deduplicates same-name entry points with identical binding identity', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const brand = Qualifier(#brand);

          abstract class BrandA {
            @inject
            @brand
            String get label;
          }

          abstract class BrandB {
            @inject
            @brand
            String get label;
          }

          @component
          abstract class DualBrandComponent implements BrandA, BrandB {}
        ''');

        final ClassElement classElement = library.getClass('DualBrandComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        expect(result.entryPoints.first.key.qualifier, 'brand');
      });

      test('preserves parent and child entry points with different qualifiers on same name', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const parent = Qualifier(#parent);
          const child = Qualifier(#child);

          abstract class ParentComponent {
            @inject
            @parent
            String get name;
          }

          abstract class ChildComponent extends ParentComponent {
            @inject
            @child
            String get name;
          }

          @component
          abstract class AppComponent implements ChildComponent {}
        ''');

        final ClassElement classElement = library.getClass('AppComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(2));
        final Set<String?> qualifiers = result.entryPoints.map((ep) => ep.key.qualifier).toSet();
        expect(qualifiers, containsAll(['parent', 'child']));
      });

      test('preserves same-name method entry points with different qualifiers from interfaces', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const fast = Qualifier(#fast);
          const slow = Qualifier(#slow);

          abstract class FastProvider {
            @inject
            @fast
            String getSpeed();
          }

          abstract class SlowProvider {
            @inject
            @slow
            String getSpeed();
          }

          @component
          abstract class EngineComponent implements FastProvider, SlowProvider {}
        ''');

        final ClassElement classElement = library.getClass('EngineComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(2));
        final Set<String?> qualifiers = result.entryPoints.map((ep) => ep.key.qualifier).toSet();
        expect(qualifiers, containsAll(['fast', 'slow']));
      });

      test('deduplicates same-name method entry points with identical binding identity', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          const turbo = Qualifier(#turbo);

          abstract class TurboA {
            @inject
            @turbo
            String getSpeed();
          }

          abstract class TurboB {
            @inject
            @turbo
            String getSpeed();
          }

          @component
          abstract class DualTurboComponent implements TurboA, TurboB {}
        ''');

        final ClassElement classElement = library.getClass('DualTurboComponent')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        expect(result.entryPoints.first.key.qualifier, 'turbo');
      });

      test('unwraps Provider<T> entry-point key to T and records isProvider', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            @inject
            Provider<CoffeeMaker> get coffeeMaker;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final EntryPoint ep = result.entryPoints.first;
        // Key derived from T (CoffeeMaker), not Provider<T>
        expect(ep.key.debugLabel, 'CoffeeMaker');
        // isProvider flag set, isFuture not set
        expect(ep.isProvider, isTrue);
        expect(ep.isFuture, isFalse);
        // Original element preserves Provider<T> return type for codegen
        final getter = ep.element as GetterElement;
        expect(getter.returnType.toString(), contains('Provider<CoffeeMaker>'));
      });

      test(
        'unwraps Provider<Future<T>> entry-point key to T and records both flags',
        () async {
          final LibraryElement library = await _resolveLibrary('''
            import 'package:inject_annotation/inject_annotation.dart';

            class CoffeeMaker {}

            @component
            abstract class CoffeeShop {
              @inject
              Provider<Future<CoffeeMaker>> get coffeeMaker;
            }
          ''');

          final ClassElement classElement = library.getClass('CoffeeShop')!;
          final ComponentData? result = componentReader.readComponent(classElement);

          expect(result, isNotNull);
          expect(result!.entryPoints, hasLength(1));
          final EntryPoint ep = result.entryPoints.first;
          // Key derived from T (CoffeeMaker), twice-unwrapped
          expect(ep.key.debugLabel, 'CoffeeMaker');
          // Both flags set
          expect(ep.isProvider, isTrue);
          expect(ep.isFuture, isTrue);
        },
      );

      test('does not unwrap Provider from a foreign package', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart' hide Provider;

          abstract class Provider<T> {
            T get();
          }

          class CoffeeMaker {}

          @component
          abstract class CoffeeShop {
            @inject
            Provider<CoffeeMaker> get coffeeMaker;
          }
        ''');

        final ClassElement classElement = library.getClass('CoffeeShop')!;
        final ComponentData? result = componentReader.readComponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        final EntryPoint ep = result.entryPoints.first;
        // Key is Provider<CoffeeMaker>, NOT unwrapped to CoffeeMaker
        expect(ep.key.debugLabel, contains('Provider'));
        expect(ep.isProvider, isFalse);
        expect(ep.isFuture, isFalse);
      });
    });
  });
}
