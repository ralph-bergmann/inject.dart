import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/component_reader.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:inject_generator/src/validation/reachability_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void _validateReachability({
  required DiagnosticReporter reporter,
  required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  required List<EntryPoint> entryPoints,
  Set<BindingKey> exemptKeys = const {},
}) {
  final result = BindingResolver(reporter: reporter)
      .resolve(modules: modules, injectables: injectables, entryPoints: entryPoints);

  ReachabilityValidator(reporter: reporter).validate(
    bindingMap: result.bindingMap,
    dependencyEdges: result.dependencyEdges,
    entryPoints: entryPoints,
    exemptKeys: exemptKeys,
  );
}

void main() {
  late DiagnosticReporter reporter;

  setUp(() {
    reporter = DiagnosticReporter();
  });

  group('ReachabilityValidator', () {
    group('validate', () {
      test('unreachable module provider produces warning', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideName() => 'coffee';

            @provides
            int provideUnused() => 42;
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateReachability(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning && m.message.contains('never used'),
        );
        expect(warnings, hasLength(1));
        expect(warnings.first.message, contains('int'));
      });

      test('unreachable injectable produces warning', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class UsedService {
            UsedService();
          }

          @inject
          class UnusedService {
            UnusedService();
          }

          @Component([])
          abstract class AppComponent {
            @inject
            UsedService get service;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement usedClass = library.getClass('UsedService')!;
        final ClassElement unusedClass = library.getClass('UnusedService')!;

        _validateReachability(
          reporter: reporter,
          modules: [],
          injectables: [
            (classElement: usedClass, injectable: reader.readInjectable(usedClass)!),
            (classElement: unusedClass, injectable: reader.readInjectable(unusedClass)!),
          ],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning && m.message.contains('never used'),
        );
        expect(warnings, hasLength(1));
        expect(warnings.first.message, contains('UnusedService'));
      });

      test('all-reachable graph produces no warnings', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            int provideCount() => 42;

            @provides
            String provideName(int count) => 'item \$count';
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateReachability(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('transitively reachable binding is not reported', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class Database {
            Database();
          }

          @inject
          class Repository {
            Repository(Database db);
          }

          @inject
          class Service {
            Service(Repository repo);
          }

          @Component([])
          abstract class AppComponent {
            @inject
            Service get service;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement dbClass = library.getClass('Database')!;
        final ClassElement repoClass = library.getClass('Repository')!;
        final ClassElement svcClass = library.getClass('Service')!;

        _validateReachability(
          reporter: reporter,
          modules: [],
          injectables: [
            (classElement: dbClass, injectable: reader.readInjectable(dbClass)!),
            (classElement: repoClass, injectable: reader.readInjectable(repoClass)!),
            (classElement: svcClass, injectable: reader.readInjectable(svcClass)!),
          ],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('empty graph produces no warnings', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @Component([])
          abstract class AppComponent {}
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;

        _validateReachability(reporter: reporter, modules: [], injectables: [], entryPoints: componentData.entryPoints);

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('bindings with no entry points are all reported as unreachable', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideName() => 'unused';

            @provides
            int provideCount() => 42;
          }

          @Component([AppModule])
          abstract class AppComponent {}
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateReachability(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning && m.message.contains('never used'),
        );
        expect(warnings, hasLength(2));
      });

      test('warning message contains binding type name and suggestion to remove', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            int provideUsed() => 42;

            @provides
            String provideUnused() => 'unused';
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            int get used;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateReachability(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning,
        );
        expect(warnings, hasLength(1));
        expect(warnings.first.message, contains('String'));
        expect(warnings.first.message, contains('never used'));
        expect(warnings.first.suggestion, contains('Remove'));
      });

      test('multiple unreachable bindings produce one warning each', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideName() => 'name';

            @provides
            int provideCount() => 42;

            @provides
            double providePrice() => 9.99;
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateReachability(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        final Iterable<DiagnosticMessage> warnings = reporter.messages.where(
          (m) => m.severity == DiagnosticSeverity.warning && m.message.contains('never used'),
        );
        expect(warnings, hasLength(2));
      });

      test('binding reachable through multiple paths is not reported', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class Shared {
            Shared();
          }

          @inject
          class Left {
            Left(Shared shared);
          }

          @inject
          class Right {
            Right(Shared shared);
          }

          @Component([])
          abstract class AppComponent {
            @inject
            Left get left;
            @inject
            Right get right;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement sharedClass = library.getClass('Shared')!;
        final ClassElement leftClass = library.getClass('Left')!;
        final ClassElement rightClass = library.getClass('Right')!;

        _validateReachability(
          reporter: reporter,
          modules: [],
          injectables: [
            (classElement: sharedClass, injectable: reader.readInjectable(sharedClass)!),
            (classElement: leftClass, injectable: reader.readInjectable(leftClass)!),
            (classElement: rightClass, injectable: reader.readInjectable(rightClass)!),
          ],
          entryPoints: componentData.entryPoints,
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('provisionListener binding is exempt from reachability warning', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }

          @module
          class AppModule {
            @provides
            String provideName() => 'coffee';

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Object> provideListener() => LoggingListener();
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        // Pass all @provisionListener keys as exempt to verify that
        // ReachabilityValidator honours the exemptKeys parameter.
        // (GraphValidator applies additional narrowing before calling this.)
        final exemptKeys = <BindingKey>{
          for (final provider in moduleData.providers)
            if (provider.metadata.isProvisionListener) provider.key,
        };

        _validateReachability(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
          exemptKeys: exemptKeys,
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });

      test('provisionListener exposed via entry point produces no warning either', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class LoggingListener implements ProvisionListener<Object> {
            @override
            void onProvision(Object instance) {}
          }

          @module
          class AppModule {
            @provides
            String provideName() => 'coffee';

            @provides
            @singleton
            @provisionListener
            ProvisionListener<Object> provideListener() => LoggingListener();
          }

          @Component([AppModule])
          abstract class AppComponent {
            @inject
            String get name;

            @inject
            ProvisionListener<Object> get listener;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement componentClass = library.getClass('AppComponent')!;
        final ComponentData componentData = reader.readComponent(componentClass)!;
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        // The listener is reachable via entry point, so even without
        // exemption it would not trigger a warning.  Pass exemptKeys anyway
        // to verify no interaction between the two mechanisms.
        final exemptKeys = <BindingKey>{
          for (final provider in moduleData.providers)
            if (provider.metadata.isProvisionListener) provider.key,
        };

        _validateReachability(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
          entryPoints: componentData.entryPoints,
          exemptKeys: exemptKeys,
        );

        expect(reporter.hasErrors, isFalse);
        expect(reporter.messages, isEmpty);
      });
    });
  });
}
