import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/async_propagator.dart';
import 'package:inject_generator/src/validation/binding_graph_result.dart';
import 'package:inject_generator/src/validation/binding_resolver.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late BindingResolver resolver;
  final propagator = AsyncPropagator();

  setUp(() {
    reporter = DiagnosticReporter();
    resolver = BindingResolver(reporter: reporter);
  });

  group('AsyncPropagator', () {
    test('marks direct async provider as async in binding map', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class AppModule {
          @provides
          @asynchronous
          String provideAsyncValue() => 'async';
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('AppModule')!;
      final moduleData = reader.readModule(moduleClass);

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
      );
      final asyncResult = propagator.propagate(graphResult);

      expect(reporter.hasErrors, isFalse);
      final asyncByLabel = {
        for (final entry in asyncResult.asyncBindings.entries) entry.key.debugLabel: entry.value,
      };
      expect(asyncByLabel['String'], isTrue, reason: 'directly-async String provider');
    });

    test('propagates async transitively through dependency chain', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class AppModule {
          @provides
          @asynchronous
          int provideAsyncInt() => 42;

          @provides
          String provideString(int value) => value.toString();
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('AppModule')!;
      final moduleData = reader.readModule(moduleClass);

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
      );
      final asyncResult = propagator.propagate(graphResult);

      expect(reporter.hasErrors, isFalse);
      final asyncByLabel = {
        for (final entry in asyncResult.asyncBindings.entries) entry.key.debugLabel: entry.value,
      };
      expect(asyncByLabel['int'], isTrue, reason: 'directly-async int provider');
      expect(asyncByLabel['String'], isTrue, reason: 'String transitively async via int dependency');
    });

    test('does not mark synchronous provider as async', () async {
      final library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class AppModule {
          @provides
          int provideInt() => 42;

          @provides
          String provideString(int value) => value.toString();
        }
      ''');

      final reader = AnnotationReader(reporter: reporter);
      final moduleClass = library.getClass('AppModule')!;
      final moduleData = reader.readModule(moduleClass);

      final graphResult = resolver.resolve(
        modules: [(moduleClass: moduleClass, moduleData: moduleData)],
        injectables: [],
      );
      final asyncResult = propagator.propagate(graphResult);

      expect(reporter.hasErrors, isFalse);
      final asyncByLabel = {
        for (final entry in asyncResult.asyncBindings.entries) entry.key.debugLabel: entry.value,
      };
      expect(asyncByLabel['int'], isFalse);
      expect(asyncByLabel['String'], isFalse);
    });

    // Story 8.1 (subcomponents): async propagation must also work across a
    // component/subcomponent boundary, mirroring how `GraphValidator
    // .validateSubcomponent` merges the parent and child graphs before
    // calling `AsyncPropagator.propagate` (see graph_validator.dart).
    group('across a component/subcomponent boundary', () {
      test('propagates an async parent binding into a child binding that depends on it', () async {
        final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class ParentModule {
            @provides
            @asynchronous
            int provideAsyncInt() => 42;
          }

          @module
          class ChildModule {
            @provides
            String provideString(int value) => value.toString();
          }
        ''');

        final reader = AnnotationReader(reporter: reporter);
        final parentModuleClass = library.getClass('ParentModule')!;
        final childModuleClass = library.getClass('ChildModule')!;
        final parentModuleData = reader.readModule(parentModuleClass);
        final childModuleData = reader.readModule(childModuleClass);

        final parentGraphResult = resolver.resolve(
          modules: [(moduleClass: parentModuleClass, moduleData: parentModuleData)],
          injectables: [],
        );

        final childResolver = BindingResolver(reporter: reporter);
        final childGraphResult = childResolver.resolve(
          modules: [(moduleClass: childModuleClass, moduleData: childModuleData)],
          injectables: [],
          parentBindings: ParentBindings(parentGraphResult.bindingMap),
        );

        // Same merge `GraphValidator.validateSubcomponent` performs before
        // running the propagator over the combined graph.
        final mergedGraphResult = BindingGraphResult(
          bindingMap: {...parentGraphResult.bindingMap, ...childGraphResult.bindingMap},
          dependencyEdges: {...parentGraphResult.dependencyEdges, ...childGraphResult.dependencyEdges},
          duplicateBindings: childGraphResult.duplicateBindings,
          parentBindingsUsed: childGraphResult.parentBindingsUsed,
        );
        final asyncResult = propagator.propagate(mergedGraphResult);

        expect(reporter.hasErrors, isFalse);
        final asyncByLabel = {
          for (final entry in asyncResult.asyncBindings.entries) entry.key.debugLabel: entry.value,
        };
        expect(asyncByLabel['int'], isTrue, reason: 'directly-async parent int provider');
        expect(
          asyncByLabel['String'],
          isTrue,
          reason: 'child String provider transitively async via the parent int dependency',
        );
        expect(childGraphResult.parentBindingsUsed.map((k) => k.debugLabel), contains('int'));
      });

      test(
        "child's own @asynchronous module makes its bindings async independent of a fully synchronous parent",
        () async {
          final library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class ParentModule {
            @provides
            int provideInt() => 42;
          }

          @module
          class ChildModule {
            @provides
            @asynchronous
            String provideAsyncString() => 'async';

            @provides
            bool provideBool(int value) => value > 0;
          }
        ''');

          final reader = AnnotationReader(reporter: reporter);
          final parentModuleClass = library.getClass('ParentModule')!;
          final childModuleClass = library.getClass('ChildModule')!;
          final parentModuleData = reader.readModule(parentModuleClass);
          final childModuleData = reader.readModule(childModuleClass);

          final parentGraphResult = resolver.resolve(
            modules: [(moduleClass: parentModuleClass, moduleData: parentModuleData)],
            injectables: [],
          );

          final childResolver = BindingResolver(reporter: reporter);
          final childGraphResult = childResolver.resolve(
            modules: [(moduleClass: childModuleClass, moduleData: childModuleData)],
            injectables: [],
            parentBindings: ParentBindings(parentGraphResult.bindingMap),
          );

          final mergedGraphResult = BindingGraphResult(
            bindingMap: {...parentGraphResult.bindingMap, ...childGraphResult.bindingMap},
            dependencyEdges: {...parentGraphResult.dependencyEdges, ...childGraphResult.dependencyEdges},
            duplicateBindings: childGraphResult.duplicateBindings,
            parentBindingsUsed: childGraphResult.parentBindingsUsed,
          );
          final asyncResult = propagator.propagate(mergedGraphResult);

          expect(reporter.hasErrors, isFalse);
          final asyncByLabel = {
            for (final entry in asyncResult.asyncBindings.entries) entry.key.debugLabel: entry.value,
          };
          expect(asyncByLabel['int'], isFalse, reason: 'parent int provider is fully synchronous');
          expect(
            asyncByLabel['String'],
            isTrue,
            reason: "child's own @asynchronous provider, unrelated to the parent",
          );
          expect(
            asyncByLabel['bool'],
            isFalse,
            reason:
                'child bool provider only depends on the synchronous parent int — must not be '
                "incorrectly tainted by the child's unrelated async String provider",
          );
        },
      );
    });
  });
}
