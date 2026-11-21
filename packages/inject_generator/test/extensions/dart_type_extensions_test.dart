import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:code_builder/code_builder.dart';
import 'package:inject_generator/src/extensions/dart_type_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('DartTypeExt typeRef / nullableTypeRef on record types', () {
    test('non-nullable record type via typeRef() emits no ?', () async {
      final DartType type = await _fieldTypeOf('(int, String) tuple = (1, "a");');

      expect(_emit(type.typeRef()), '(int, String)');
    });

    test('already-nullable record type via typeRef() preserves single ?', () async {
      final DartType type = await _fieldTypeOf('(int, String)? tuple = null;');

      expect(_emit(type.typeRef()), '(int, String)?');
    });

    test('non-nullable record type via nullableTypeRef() adds single ?', () async {
      final DartType type = await _fieldTypeOf('(int, String) tuple = (1, "a");');

      expect(_emit(type.nullableTypeRef()), '(int, String)?');
    });

    test('already-nullable record type via nullableTypeRef() stays single ? (no double ??)', () async {
      final DartType type = await _fieldTypeOf('(int, String)? tuple = null;');

      expect(_emit(type.nullableTypeRef()), '(int, String)?');
    });
  });

  group('DartTypeExt typeRef / nullableTypeRef display-string fallback', () {
    // A type parameter is neither an InterfaceType, an alias, a function type
    // nor a record type, so it takes the display-string fallback.

    test('already-nullable type parameter via nullableTypeRef() stays single ? (no double ??)', () async {
      // The fallback used to append `?` blindly, producing `T??` when the type
      // was already nullable and forceNullable was true.
      final DartType type = await _fieldTypeOf('T? value = null;');

      expect(_emit(type.nullableTypeRef()), 'T?');
    });
  });
}

/// Resolves a generic class with a single field of the given declaration and
/// returns the resolved [DartType] of that field.
Future<DartType> _fieldTypeOf(String fieldDecl) async {
  final LibraryElement library = await resolveSource(
    '''
      class Holder<T> {
        final $fieldDecl
      }
    ''',
    (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
    readAllSourcesFromFilesystem: true,
  );
  final ClassElement holder = library.getClass('Holder')!;
  return holder.fields.first.type;
}

String _emit(Reference ref) => ref.accept(DartEmitter(useNullSafetySyntax: true)).toString();
