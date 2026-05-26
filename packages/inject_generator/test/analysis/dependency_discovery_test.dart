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
