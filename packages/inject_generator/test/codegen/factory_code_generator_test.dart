import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/annotation_reader.dart';
import 'package:inject_generator/src/codegen/factory_code_generator.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:test/test.dart';

void main() {
  group('FactoryCodeGenerator', () {
    late DiagnosticReporter reporter;
    late AnnotationReader reader;
    late FactoryCodeGenerator generator;

    setUp(() {
      reporter = DiagnosticReporter();
      reader = AnnotationReader(reporter: reporter);
      generator = FactoryCodeGenerator();
    });

    test(
      'emits only abstract factories for synthesized @assistedInject constructors',
      () async {
        // .factory.dart only carries the synthesized abstract factory classes;
        // the concrete implementations live in .inject.dart. Even when a
        // dependency is unresolvable at factory-builder analysis time (here
        // LatteFactory is a synthesized type with no defining class), the
        // abstract class must still be emitted so user code can reference it.
        final LibraryElement library = await resolveSource(
          '''
          import 'package:inject_annotation/inject_annotation.dart';

          class Latte {
            @assistedInject
            Latte(@assisted this.name);
            final String name;
          }

          class CoffeeApp {
            @assistedInject
            CoffeeApp(this.latteFactory, @assisted this.id);
            final LatteFactory latteFactory;
            final int id;
          }
          ''',
          (resolver) async => resolver.libraryFor(
            AssetId('_resolve_source', 'lib/_resolve_source.dart'),
          ),
          readAllSourcesFromFilesystem: true,
        );

        final String? output = generator.generate(library: library, reader: reader);

        expect(output, isNotNull);
        expect(output, contains('abstract class CoffeeAppFactory'));
        expect(output, contains('abstract class LatteFactory'));
        expect(output, isNot(contains('\$Impl')));
        expect(output, isNot(contains('_invalidType\$Provider')));
      },
    );
  });
}
