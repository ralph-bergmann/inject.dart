import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/analysis/entry_point_collector.dart';
import 'package:inject_generator/src/analysis/inject_reader.dart';
import 'package:inject_generator/src/analysis/module_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:inject_generator/src/validation/cycle_validator.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void _validateCycles({
  required DiagnosticReporter reporter,
  required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
  required List<({ClassElement classElement, InjectableData injectable})> injectables,
  List<EntryPoint> entryPoints = const [],
}) {
  final result = BindingResolver(
    reporter: reporter,
  ).resolve(modules: modules, injectables: injectables, entryPoints: entryPoints);

  CycleValidator(reporter: reporter).validate(
    bindingMap: result.bindingMap,
    dependencyEdges: result.dependencyEdges,
  );
}

void main() {
  late DiagnosticReporter reporter;

  setUp(() {
    reporter = DiagnosticReporter();
  });

  group('CycleValidator', () {
    group('validate', () {
      test('reports error for simple cycle A → B → A', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideA(int b) => 'a';

            @provides
            int provideB(String a) => 42;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateCycles(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors, isNotEmpty);
      });

      test('reports error for self-cycle A → A', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideA(String a) => a;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateCycles(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors, isNotEmpty);
        expect(cycleErrors.first.message, contains('String'));
      });

      test('reports error for longer cycle A → B → C → A', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class ServiceA {
            ServiceA(ServiceB b);
          }

          @inject
          class ServiceB {
            ServiceB(ServiceC c);
          }

          @inject
          class ServiceC {
            ServiceC(ServiceA a);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement classA = library.getClass('ServiceA')!;
        final ClassElement classB = library.getClass('ServiceB')!;
        final ClassElement classC = library.getClass('ServiceC')!;
        final InjectableData injectableA = reader.readInjectable(classA)!;
        final InjectableData injectableB = reader.readInjectable(classB)!;
        final InjectableData injectableC = reader.readInjectable(classC)!;

        _validateCycles(
          reporter: reporter,
          modules: [],
          injectables: [
            (classElement: classA, injectable: injectableA),
            (classElement: classB, injectable: injectableB),
            (classElement: classC, injectable: injectableC),
          ],
        );

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors, isNotEmpty);
        // Cycle path should include all three participants
        final String message = cycleErrors.first.message;
        expect(message, contains('ServiceA'));
        expect(message, contains('ServiceB'));
        expect(message, contains('ServiceC'));
      });

      test('reports multiple independent cycles', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            // Cycle 1: String ↔ int
            @provides
            String provideA(int b) => 'a';

            @provides
            int provideB(String a) => 42;

            // Cycle 2: double ↔ bool
            @provides
            double provideC(bool d) => 1.0;

            @provides
            bool provideD(double c) => true;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateCycles(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors.length, greaterThanOrEqualTo(2));
      });

      test('does not report false positive for diamond dependency', () async {
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

          @inject
          class Top {
            Top(Left left, Right right);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement sharedClass = library.getClass('Shared')!;
        final ClassElement leftClass = library.getClass('Left')!;
        final ClassElement rightClass = library.getClass('Right')!;
        final ClassElement topClass = library.getClass('Top')!;

        _validateCycles(
          reporter: reporter,
          modules: [],
          injectables: [
            (classElement: sharedClass, injectable: reader.readInjectable(sharedClass)!),
            (classElement: leftClass, injectable: reader.readInjectable(leftClass)!),
            (classElement: rightClass, injectable: reader.readInjectable(rightClass)!),
            (classElement: topClass, injectable: reader.readInjectable(topClass)!),
          ],
        );

        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors, isEmpty);
      });

      test('does not report false positive for shared dependency from multiple paths', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            int provideCount() => 42;

            @provides
            String provideName(int count) => 'name';

            @provides
            double providePrice(int count) => 9.99;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateCycles(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors, isEmpty);
      });

      test('does not report errors for acyclic graph', () async {
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
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement dbClass = library.getClass('Database')!;
        final ClassElement repoClass = library.getClass('Repository')!;
        final ClassElement svcClass = library.getClass('Service')!;

        _validateCycles(
          reporter: reporter,
          modules: [],
          injectables: [
            (classElement: dbClass, injectable: reader.readInjectable(dbClass)!),
            (classElement: repoClass, injectable: reader.readInjectable(repoClass)!),
            (classElement: svcClass, injectable: reader.readInjectable(svcClass)!),
          ],
        );

        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleErrors, isEmpty);
      });

      test('diagnostic contains human-readable cycle path via debugLabel', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @inject
          class Alpha {
            Alpha(Beta b);
          }

          @inject
          class Beta {
            Beta(Alpha a);
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement alphaClass = library.getClass('Alpha')!;
        final ClassElement betaClass = library.getClass('Beta')!;

        _validateCycles(
          reporter: reporter,
          modules: [],
          injectables: [
            (classElement: alphaClass, injectable: reader.readInjectable(alphaClass)!),
            (classElement: betaClass, injectable: reader.readInjectable(betaClass)!),
          ],
        );

        expect(reporter.hasErrors, isTrue);
        final DiagnosticMessage cycleError = reporter.messages.firstWhere(
          (m) => m.message.contains('Circular dependency'),
        );
        // Should contain the arrow-separated cycle path
        expect(cycleError.message, contains('→'));
        // Should use debugLabel (human-readable type names, not internal identities)
        expect(cycleError.message, contains('Alpha'));
        expect(cycleError.message, contains('Beta'));
      });

      test('diagnostic contains actionable suggestion', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideA(int b) => 'a';

            @provides
            int provideB(String a) => 42;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateCycles(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final DiagnosticMessage cycleError = reporter.messages.firstWhere(
          (m) => m.message.contains('Circular dependency'),
        );
        expect(cycleError.suggestion, contains('Provider<T>'));
      });

      test('reports at least one cycle when overlapping cycles share nodes', () async {
        // Graph: A→B, A→C, B→C, C→A creates two cycles:
        // A→B→C→A and A→C→A. DFS with visited/in-stack reports at least
        // one per strongly connected component (not necessarily all simple
        // cycles). This documents the expected algorithm behavior.
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideA(int b, double c) => 'a';

            @provides
            int provideB(double c) => 42;

            @provides
            double provideC(String a) => 1.0;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateCycles(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        // At least one cycle is reported from the SCC
        expect(cycleErrors, isNotEmpty);
      });

      test('does not report duplicate diagnostics for duplicate dependency edges', () async {
        // A provider with two parameters of the same type produces only
        // one dependency edge (deduplication via Set), so at most one
        // cycle diagnostic is emitted per back-edge.
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class AppModule {
            @provides
            String provideA(int b1, int b2) => '\$b1\$b2';

            @provides
            int provideB(String a) => 42;
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final ClassElement moduleClass = library.getClass('AppModule')!;
        final ModuleData moduleData = reader.readModule(moduleClass);

        _validateCycles(
          reporter: reporter,
          modules: [(moduleClass: moduleClass, moduleData: moduleData)],
          injectables: [],
        );

        expect(reporter.hasErrors, isTrue);
        final Iterable<DiagnosticMessage> cycleErrors = reporter.messages.where(
          (m) => m.message.contains('Circular dependency'),
        );
        // Exactly one cycle, not duplicated
        expect(cycleErrors.length, equals(1));
      });
    });
  });
}
