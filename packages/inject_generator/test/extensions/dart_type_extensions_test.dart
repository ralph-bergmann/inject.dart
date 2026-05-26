import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:code_builder/code_builder.dart';
import 'package:inject_generator/src/extensions/dart_type_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('DartTypeExt typeRef / nullableTypeRef fallback', () {
    // The fallback branch in _buildTypeRef is reached for types that are
    // neither InterfaceType nor an aliased typedef. RecordType literals
    // (without a typedef alias) take that path.

    test('non-nullable record type via typeRef() emits bare symbol', () async {
      final DartType type = await _recordTypeOf('(int, String) tuple = (1, "a");');

      expect(_symbol(type.typeRef()), '(int, String)');
    });

    test('already-nullable record type via typeRef() preserves single ?', () async {
      final DartType type = await _recordTypeOf('(int, String)? tuple = null;');

      expect(_symbol(type.typeRef()), '(int, String)?');
    });

    test('non-nullable record type via nullableTypeRef() adds single ?', () async {
      final DartType type = await _recordTypeOf('(int, String) tuple = (1, "a");');

      expect(_symbol(type.nullableTypeRef()), '(int, String)?');
    });

    test('already-nullable record type via nullableTypeRef() stays single ? (no double ??)', () async {
      // Regression for an already-nullable record type:
      // `_buildTypeRef` used to concat `'$display?'` blindly, producing
      // `Type??` when the type was already nullable AND forceNullable=true.
      final DartType type = await _recordTypeOf('(int, String)? tuple = null;');

      expect(_symbol(type.nullableTypeRef()), '(int, String)?');
    });
  });
}

/// Resolves a class with a single field of the given declaration and returns
/// the resolved [DartType] of that field.
Future<DartType> _recordTypeOf(String fieldDecl) async {
  final LibraryElement library = await resolveSource(
    '''
      class Holder {
        final $fieldDecl
      }
    ''',
    (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
    readAllSourcesFromFilesystem: true,
  );
  final ClassElement holder = library.getClass('Holder')!;
  return holder.fields.first.type;
}

String _symbol(Reference ref) => ref.symbol!;
