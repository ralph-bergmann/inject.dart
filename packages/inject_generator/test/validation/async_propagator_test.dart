import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:inject_generator/src/validation/async_propagator.dart';
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
  });
}
