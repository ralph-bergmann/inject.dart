import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
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
  late EntryPointCollector collector;

  setUp(() {
    reporter = DiagnosticReporter();
    collector = EntryPointCollector(reporter: reporter);
  });

  group('EntryPointCollector', () {
    test('collects entry points from the class and all supertypes', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Foo {
          @inject
          const Foo();
        }

        class Bar {
          @inject
          const Bar();
        }

        abstract class HasFoo {
          Foo get foo;
        }

        @component
        abstract class C implements HasFoo {
          Bar get bar;
        }
      ''');

      final ClassElement classElement = library.getClass('C')!;
      final List<EntryPoint> entryPoints = collector.collectEntryPoints(classElement);

      expect(entryPoints.map((e) => e.element.name), containsAll(['foo', 'bar']));
    });

    test('deduplicates by (name, BindingKey)', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Foo {
          @inject
          const Foo();
        }

        abstract class HasFoo {
          Foo get foo;
        }

        @component
        abstract class C implements HasFoo {
          @override
          Foo get foo;
        }
      ''');

      final ClassElement classElement = library.getClass('C')!;
      final List<EntryPoint> entryPoints = collector.collectEntryPoints(classElement);

      expect(entryPoints, hasLength(1), reason: 'same name + same key must be deduplicated');
    });

    test('keeps same-named getters with different qualifiers', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        const blue = Qualifier(#blue);

        class Foo {
          @inject
          const Foo();
        }

        abstract class HasFoo {
          Foo get foo;
        }

        @component
        abstract class C implements HasFoo {
          @override
          @blue
          Foo get foo;
        }
      ''');

      final ClassElement classElement = library.getClass('C')!;
      final List<EntryPoint> entryPoints = collector.collectEntryPoints(classElement);

      expect(entryPoints, hasLength(2), reason: 'different qualifiers create distinct binding keys');
    });

    test('sorts entry points by source offset', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Zebra {
          @inject
          const Zebra();
        }

        class Apple {
          @inject
          const Apple();
        }

        @component
        abstract class C {
          Zebra get zebra;
          Apple get apple;
        }
      ''');

      final ClassElement classElement = library.getClass('C')!;
      final List<EntryPoint> entryPoints = collector.collectEntryPoints(classElement);

      expect(entryPoints.map((e) => e.element.name), ['zebra', 'apple'], reason: 'declaration order, not alphabetical');
    });

    test('unwraps Future and Provider wrappers into flags', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class Foo {
          @inject
          const Foo();
        }

        @component
        abstract class C {
          Future<Foo> get futureFoo;
          Provider<Foo> get fooProvider;
        }
      ''');

      final ClassElement classElement = library.getClass('C')!;
      final List<EntryPoint> entryPoints = collector.collectEntryPoints(classElement);

      expect(entryPoints, hasLength(2));
      expect(entryPoints[0].isFuture, isTrue);
      expect(entryPoints[0].isProvider, isFalse);
      expect(entryPoints[1].isProvider, isTrue);
      expect(entryPoints[1].isFuture, isFalse);
    });

    test('reports unsupported entry point types', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @component
        abstract class C {
          (int, String) get record;
        }
      ''');

      final ClassElement classElement = library.getClass('C')!;
      final List<EntryPoint> entryPoints = collector.collectEntryPoints(classElement);

      expect(entryPoints, isEmpty);
      expect(reporter.hasErrors, isTrue);
      expect(reporter.messages.first.message, contains('Record type'));
    });
  });
}
