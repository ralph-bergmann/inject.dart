import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/extensions/element_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('ElementExt resolvePublicUri', () {
    group('without sourceUri (absolute package URIs)', () {
      test('returns package URI for public library element', () async {
        final library = await _resolve('''
          class Foo {}
        ''');
        final element = library.getClass('Foo');

        var uri = '';
        if (element case final Element e) {
          uri = e.resolvePublicUri();
        }

        expect(uri, 'package:_resolve_source/_resolve_source.dart');
      });

      test('preserves /src/ path for external package', () async {
        final library = await _resolve('''
          import 'package:inject_annotation/inject_annotation.dart';
          class Foo { late Provider p; }
        ''');
        // Provider lives under src/ internally in inject_annotation.
        // Access it via the type of a field.
        final foo = library.getClass('Foo');
        final providerType = foo.fields.first.type;
        final providerElement = (providerType as dynamic).element;

        var uri = '';
        if (providerElement case final Element e) {
          uri = e.resolvePublicUri();
        }

        // The real library URI is preserved (no barrel rewrite)
        expect(uri, 'package:inject_annotation/src/api/provider.dart');
      });

      test('preserves dart: URIs unchanged', () async {
        final library = await _resolve('''
          class Wrapper {
            final List<int> items = [];
          }
        ''');
        // Get the List type's element from dart:core
        final wrapper = library.getClass('Wrapper');
        final field = wrapper.fields.first;
        final listType = field.type;
        final listElement = (listType as dynamic).element;

        var uri = '';
        if (listElement case final Element e) {
          uri = e.resolvePublicUri();
        }

        expect(uri, startsWith('dart:'));
      });
    });

    group('with sourceUri (relative imports)', () {
      test('returns relative path for same-package element in same directory', () async {
        final library = await _resolve('''
          class Foo {}
        ''');
        final element = library.getClass('Foo');

        var uri = '';
        if (element case final Element e) {
          uri = e.resolvePublicUri(sourceUri: 'package:_resolve_source/my_component.dart');
        }

        expect(uri, '_resolve_source.dart');
      });

      test('returns relative path with subdirectory navigation', () async {
        final library = await _resolve('''
          class Foo {}
        ''');
        final element = library.getClass('Foo');

        // Source is in a subdirectory, target is at package root
        var uri = '';
        if (element case final Element e) {
          uri = e.resolvePublicUri(sourceUri: 'package:_resolve_source/src/components/my_component.dart');
        }

        expect(uri, '../../_resolve_source.dart');
      });

      test('keeps full package URI for different package', () async {
        final library = await _resolve('''
          import 'package:inject_annotation/inject_annotation.dart';
          class Foo { late Provider p; }
        ''');
        final foo = library.getClass('Foo');
        final providerType = foo.fields.first.type;
        final providerElement = (providerType as dynamic).element;

        var uri = '';
        if (providerElement case final Element e) {
          uri = e.resolvePublicUri(sourceUri: 'package:_resolve_source/_resolve_source.dart');
        }

        // Different package: preserved as-is including /src/ path
        expect(uri, 'package:inject_annotation/src/api/provider.dart');
      });

      test('keeps dart: URI even when sourceUri is provided', () async {
        final library = await _resolve('''
          class Wrapper {
            final List<int> items = [];
          }
        ''');
        final wrapper = library.getClass('Wrapper');
        final field = wrapper.fields.first;
        final listType = field.type;
        final listElement = (listType as dynamic).element;

        var uri = '';
        if (listElement case final Element e) {
          uri = e.resolvePublicUri(sourceUri: 'package:_resolve_source/_resolve_source.dart');
        }

        expect(uri, startsWith('dart:'));
      });

      test('returns relative path for same-package /src/ element', () async {
        final library = await _resolve('''
          import 'package:inject_annotation/inject_annotation.dart';
          class Foo { late Provider p; }
        ''');
        final foo = library.getClass('Foo');
        final providerType = foo.fields.first.type;
        final providerElement = (providerType as dynamic).element;

        // sourceUri is inside inject_annotation; since Provider
        // also lives in inject_annotation, same-package → relative path
        var uri = '';
        if (providerElement case final Element e) {
          uri = e.resolvePublicUri(sourceUri: 'package:inject_annotation/some_file.dart');
        }

        expect(uri, 'src/api/provider.dart');
      });
    });

    group('edge cases', () {
      test('sourceUri null does not trigger relative resolution', () async {
        final library = await _resolve('''
          class Foo {}
        ''');
        final element = library.getClass('Foo');

        var uri = '';
        if (element case final Element e) {
          uri = e.resolvePublicUri();
        }

        expect(uri, 'package:_resolve_source/_resolve_source.dart');
      });

      test('same file reference returns self-relative path', () async {
        final library = await _resolve('''
          class Foo {}
        ''');
        final element = library.getClass('Foo');

        var uri = '';
        if (element case final Element e) {
          uri = e.resolvePublicUri(sourceUri: 'package:_resolve_source/_resolve_source.dart');
        }

        // Same file -> relative path is just the filename
        expect(uri, '_resolve_source.dart');
      });

      test('handles deeply nested source path', () async {
        final library = await _resolve('''
          class Foo {}
        ''');
        final element = library.getClass('Foo');

        var uri = '';
        if (element case final Element e) {
          uri = e.resolvePublicUri(sourceUri: 'package:_resolve_source/features/auth/login/login_component.dart');
        }

        expect(uri, '../../../_resolve_source.dart');
      });
    });
  });
}

/// Resolves inline Dart source into a [LibraryElement] using
/// the synthetic `_resolve_source` package (same as golden_helper).
Future<dynamic> _resolve(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);
