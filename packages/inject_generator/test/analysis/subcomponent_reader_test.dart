import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/subcomponent_reader.dart';
import 'package:inject_generator/src/logging/diagnostic_reporter.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  late DiagnosticReporter reporter;
  late SubcomponentReader subcomponentReader;

  setUp(() {
    reporter = DiagnosticReporter();
    subcomponentReader = SubcomponentReader(reporter: reporter);
  });

  group('SubcomponentReader', () {
    group('module extraction', () {
      test('reads @subcomponent with zero modules', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @subcomponent
          abstract class HttpSubcomponent {}
        ''');

        final ClassElement classElement = library.getClass('HttpSubcomponent')!;
        final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules, isEmpty);
        expect(reporter.hasErrors, isFalse);
      });

      test('reads @Subcomponent with modules in declaration order', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class HttpModule {}

          @module
          class CacheModule {}

          @Subcomponent([HttpModule, CacheModule])
          abstract class HttpSubcomponent {}
        ''');

        final ClassElement classElement = library.getClass('HttpSubcomponent')!;
        final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules.map((m) => m.element?.name), ['HttpModule', 'CacheModule']);
      });

      test('reports duplicate module in @Subcomponent as error', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class M {}

          @Subcomponent([M, M])
          abstract class S {}
        ''');

        final ClassElement classElement = library.getClass('S')!;
        final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement);

        expect(result, isNotNull);
        expect(result!.modules, hasLength(1), reason: 'duplicate must be dropped from modules list');
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('listed more than once'));
      });

      test('reports a @subcomponent-annotated type in the @Subcomponent module list as an error', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @module
          class HttpModule {}

          @subcomponent
          abstract class InnerSubcomponent {}

          @Subcomponent([HttpModule, InnerSubcomponent])
          abstract class OuterSubcomponent {}
        ''');

        final ClassElement classElement = library.getClass('OuterSubcomponent')!;
        final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement);

        expect(result, isNotNull);
        expect(
          result!.modules.map((m) => m.element?.name),
          ['HttpModule'],
          reason: 'the @subcomponent entry must be dropped from the module list',
        );
        expect(reporter.hasErrors, isTrue);
        final DiagnosticMessage message = reporter.messages.firstWhere((m) => m.message.contains('InnerSubcomponent'));
        expect(message.message, contains('annotated with @subcomponent'));
        expect(message.message, contains("@Subcomponent([...]) on 'OuterSubcomponent'"));
        expect(message.suggestion, contains('@Module(subcomponents: [InnerSubcomponent])'));
      });

      test(
        'validate: false suppresses the @subcomponent-in-module-list diagnostic but still drops the entry',
        () async {
          final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          @subcomponent
          abstract class InnerSubcomponent {}

          @Subcomponent([InnerSubcomponent])
          abstract class OuterSubcomponent {}
        ''');

          final ClassElement classElement = library.getClass('OuterSubcomponent')!;
          final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement, validate: false);

          expect(result, isNotNull);
          expect(result!.modules, isEmpty, reason: 'the invalid entry is dropped even without validation');
          expect(reporter.hasErrors, isFalse, reason: 'validate: false must not report the diagnostic');
        },
      );

      test('reports missing annotation metadata as error', () async {
        final LibraryElement library = await _resolveLibrary('''
          abstract class NotAnnotated {}
        ''');

        final ClassElement classElement = library.getClass('NotAnnotated')!;
        final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement);

        expect(result, isNull);
        expect(reporter.hasErrors, isTrue);
        expect(reporter.messages.first.message, contains('@subcomponent'));
      });
    });

    group('entry point extraction', () {
      test('collects abstract getters and @inject methods as entry points', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class ApiService {
            @inject
            const ApiService();
          }

          class HttpClient {
            @inject
            const HttpClient();
          }

          @subcomponent
          abstract class HttpSubcomponent {
            ApiService get apiService;

            @inject
            HttpClient httpClient();
          }
        ''');

        final ClassElement classElement = library.getClass('HttpSubcomponent')!;
        final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(2));
        expect(result.entryPoints[0].element.name, 'apiService');
        expect(result.entryPoints[1].element.name, 'httpClient');
      });

      test('collects entry points from super-interfaces', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'package:inject_annotation/inject_annotation.dart';

          class ApiService {
            @inject
            const ApiService();
          }

          abstract class HasApi {
            ApiService get apiService;
          }

          @subcomponent
          abstract class HttpSubcomponent implements HasApi {}
        ''');

        final ClassElement classElement = library.getClass('HttpSubcomponent')!;
        final SubcomponentData? result = subcomponentReader.readSubcomponent(classElement);

        expect(result, isNotNull);
        expect(result!.entryPoints, hasLength(1));
        expect(result.entryPoints.single.element.name, 'apiService');
      });
    });
  });

  group('SubcomponentReader.readSubcomponentFactory', () {
    test('value-param-only factory: classifies the sole parameter as a value parameter', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @subcomponent
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(String userId);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNotNull);
      expect(result!.subcomponentClass.name, 'ApiSubcomponent');
      expect(result.moduleParameters, isEmpty);
      expect(result.valueParameters, hasLength(1));
      expect(result.valueParameters.single.parameter.name, 'userId');
      expect(reporter.hasErrors, isFalse);
    });

    test('mixed module + value parameters: both compose independently', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class ApiModule {}

        @Subcomponent([ApiModule])
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(ApiModule module, String userId);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNotNull);
      expect(result!.moduleParameters, hasLength(1));
      expect(result.moduleParameters.single.moduleClass.name, 'ApiModule');
      expect(result.valueParameters, hasLength(1));
      expect(result.valueParameters.single.parameter.name, 'userId');
      expect(reporter.hasErrors, isFalse);
    });

    test('qualified value parameter: qualifier is extracted', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        const apiKey = Qualifier(#apiKey);

        @subcomponent
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(@apiKey String key);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNotNull);
      expect(result!.valueParameters.single.qualifier, 'apiKey');
      expect(reporter.hasErrors, isFalse);
    });

    test('nullable value parameter: type keeps its nullability', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @subcomponent
        abstract class ApiSubcomponent {
          String? get sessionToken;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(String? sessionToken);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNotNull);
      expect(result!.valueParameters.single.type.getDisplayString(), 'String?');
    });

    test('reports error when the class is not abstract', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @subcomponent
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        class ApiSubcomponentFactory {}
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNull);
      expect(reporter.hasErrors, isTrue);
    });

    test('reports error when the factory has zero abstract methods', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {}
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNull);
      expect(reporter.hasErrors, isTrue);
    });

    test('reports error when the factory has more than one abstract method', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @subcomponent
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(String userId);
          ApiSubcomponent createOther(String userId);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNull);
      expect(reporter.hasErrors, isTrue);
    });

    test('reports error when the return type is not a class', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @subcomponentFactory
        abstract class BadFactory {
          String create(String userId);
        }
      ''');

      final ClassElement classElement = library.getClass('BadFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNull);
      expect(reporter.hasErrors, isTrue);
    });

    test('reports error when the return type is not annotated with @subcomponent', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        class NotASubcomponent {}

        @subcomponentFactory
        abstract class BadFactory {
          NotASubcomponent create(String userId);
        }
      ''');

      final ClassElement classElement = library.getClass('BadFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNull);
      expect(reporter.hasErrors, isTrue);
    });

    test('reports error for a module parameter declared more than once', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class ApiModule {}

        @Subcomponent([ApiModule])
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(ApiModule a, ApiModule b);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNotNull);
      expect(result!.moduleParameters, hasLength(1));
      expect(reporter.hasErrors, isTrue);
    });

    test('reports error when a required (no-default-ctor) module is missing from the factory params', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class ApiModule {
          ApiModule(String baseUrl);
        }

        @Subcomponent([ApiModule])
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(String userId);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(classElement);

      expect(result, isNotNull);
      expect(reporter.hasErrors, isTrue);
    });

    test('validate: false suppresses all diagnostics', () async {
      final LibraryElement library = await _resolveLibrary('''
        import 'package:inject_annotation/inject_annotation.dart';

        @module
        class ApiModule {
          ApiModule(String baseUrl);
        }

        @Subcomponent([ApiModule])
        abstract class ApiSubcomponent {
          String get userId;
        }

        @subcomponentFactory
        abstract class ApiSubcomponentFactory {
          ApiSubcomponent create(String userId);
        }
      ''');

      final ClassElement classElement = library.getClass('ApiSubcomponentFactory')!;
      final SubcomponentFactoryData? result = subcomponentReader.readSubcomponentFactory(
        classElement,
        validate: false,
      );

      expect(result, isNotNull);
      expect(reporter.hasErrors, isFalse);
    });
  });
}
