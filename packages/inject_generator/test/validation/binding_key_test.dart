import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

DartType _getFieldType(LibraryElement library, String className, String fieldName) {
  final ClassElement classElement = library.getClass(className)!;
  final FieldElement field = classElement.fields.firstWhere((f) => f.name == fieldName);
  return field.type;
}

DartType _getClassType(LibraryElement library, String className) {
  final ClassElement classElement = library.getClass(className)!;
  return classElement.thisType;
}

void main() {
  group('BindingKey', () {
    group('fromDartType', () {
      test('treats same type from same library as equal', () async {
        final LibraryElement library = await _resolveLibrary('''
          class MyService {}
          class Holder {
            late MyService a;
            late MyService b;
          }
        ''');

        final DartType typeA = _getFieldType(library, 'Holder', 'a');
        final DartType typeB = _getFieldType(library, 'Holder', 'b');

        final BindingKey? keyA = BindingKey.fromDartType(typeA);
        final BindingKey? keyB = BindingKey.fromDartType(typeB);

        expect(keyA, isNotNull);
        expect(keyB, isNotNull);
        expect(keyA, equals(keyB));
        expect(keyA.hashCode, equals(keyB.hashCode));
      });

      test('treats types from different libraries as different', () async {
        // String comes from dart:core, Future from dart:async — different library
        // URIs produce different binding keys. A true same-name-different-library
        // test requires multi-package resolution not available in this setup.
        final LibraryElement library = await _resolveLibrary('''
          import 'dart:async';
          class Holder {
            late String coreType;
            late Future<void> asyncType;
          }
        ''');

        final DartType coreType = _getFieldType(library, 'Holder', 'coreType');
        final DartType asyncType = _getFieldType(library, 'Holder', 'asyncType');

        final BindingKey? keyCore = BindingKey.fromDartType(coreType);
        final BindingKey? keyAsync = BindingKey.fromDartType(asyncType);

        expect(keyCore, isNotNull);
        expect(keyAsync, isNotNull);
        // Types from different libraries produce different keys
        expect(keyCore, isNot(equals(keyAsync)));
      });

      test('treats List<String> and List<int> as different', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late List<String> strings;
            late List<int> ints;
          }
        ''');

        final DartType stringListType = _getFieldType(library, 'Holder', 'strings');
        final DartType intListType = _getFieldType(library, 'Holder', 'ints');

        final BindingKey? keyStrings = BindingKey.fromDartType(stringListType);
        final BindingKey? keyInts = BindingKey.fromDartType(intListType);

        expect(keyStrings, isNotNull);
        expect(keyInts, isNotNull);
        expect(keyStrings, isNot(equals(keyInts)));
      });

      test('treats List<Comparable<String>> without entering endless loop', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late List<Comparable<String>> nested;
          }
        ''');

        final DartType nestedType = _getFieldType(library, 'Holder', 'nested');

        // Must complete without timeout or stack overflow
        final BindingKey? key = BindingKey.fromDartType(nestedType);

        expect(key, isNotNull);
        expect(key!.debugLabel, contains('List'));
        expect(key.debugLabel, contains('Comparable'));
      });

      test('includes qualifier in identity', () async {
        final LibraryElement library = await _resolveLibrary('''
          class MyService {}
        ''');

        final DartType dartType = _getClassType(library, 'MyService');

        final BindingKey? keyWithout = BindingKey.fromDartType(dartType);
        final BindingKey? keyWithA = BindingKey.fromDartType(dartType, qualifier: 'a');
        final BindingKey? keyWithB = BindingKey.fromDartType(dartType, qualifier: 'b');
        final BindingKey? keyWithA2 = BindingKey.fromDartType(dartType, qualifier: 'a');

        expect(keyWithout, isNot(equals(keyWithA)));
        expect(keyWithA, isNot(equals(keyWithB)));
        expect(keyWithA, equals(keyWithA2));
        // HashCode must be pairwise distinct for the three distinct qualifiers.
        expect(keyWithout!.hashCode, isNot(equals(keyWithA!.hashCode)));
        expect(keyWithA.hashCode, isNot(equals(keyWithB!.hashCode)));
        expect(keyWithout.hashCode, isNot(equals(keyWithB.hashCode)));
        // == is symmetric: a == b ↔ b == a.
        expect(keyWithA2, equals(keyWithA));
      });

      test('treats nullable and non-nullable as different', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late String nonNullable;
            late String? nullable;
          }
        ''');

        final DartType nonNullableType = _getFieldType(library, 'Holder', 'nonNullable');
        final DartType nullableType = _getFieldType(library, 'Holder', 'nullable');

        final BindingKey? keyNonNullable = BindingKey.fromDartType(nonNullableType);
        final BindingKey? keyNullable = BindingKey.fromDartType(nullableType);

        expect(keyNonNullable, isNotNull);
        expect(keyNullable, isNotNull);
        expect(keyNonNullable, isNot(equals(keyNullable)));
      });

      test('isNullable returns true for nullable key, false otherwise', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late String nonNullable;
            late String? nullable;
          }
        ''');

        final DartType nonNullableType = _getFieldType(library, 'Holder', 'nonNullable');
        final DartType nullableType = _getFieldType(library, 'Holder', 'nullable');

        final BindingKey keyNonNullable = BindingKey.fromDartType(nonNullableType)!;
        final BindingKey keyNullable = BindingKey.fromDartType(nullableType)!;

        expect(keyNonNullable.isNullable, isFalse);
        expect(keyNullable.isNullable, isTrue);
      });

      test('nonNullable strips top-level ? and equals the non-nullable key', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late String nonNullable;
            late String? nullable;
          }
        ''');

        final BindingKey keyNullable = BindingKey.fromDartType(
          _getFieldType(library, 'Holder', 'nullable'),
        )!;
        final BindingKey keyNonNullable = BindingKey.fromDartType(
          _getFieldType(library, 'Holder', 'nonNullable'),
        )!;

        expect(keyNullable.nonNullable, equals(keyNonNullable));
        expect(keyNullable.nonNullable.qualifier, isNull);
      });

      test('nonNullable preserves qualifier when stripping nullability', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late String nonNullable;
            late String? nullable;
          }
        ''');

        const qualifier = 'prod';
        final BindingKey keyNullable = BindingKey.fromDartType(
          _getFieldType(library, 'Holder', 'nullable'),
          qualifier: qualifier,
        )!;
        final BindingKey keyNonNullable = BindingKey.fromDartType(
          _getFieldType(library, 'Holder', 'nonNullable'),
          qualifier: qualifier,
        )!;

        expect(keyNullable.nonNullable, equals(keyNonNullable));
        expect(keyNullable.nonNullable.qualifier, equals(qualifier));
      });

      test('produces readable debugLabel for diagnostics', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late List<Comparable<String>> nested;
          }
        ''');

        final DartType nestedType = _getFieldType(library, 'Holder', 'nested');

        final BindingKey? key = BindingKey.fromDartType(nestedType, qualifier: 'myQualifier');

        expect(key, isNotNull);
        // debugLabel should be human-readable, not the normalized identity
        expect(key!.debugLabel, contains('List'));
        expect(key.debugLabel, contains('#myQualifier'));
        // Nested generics must not leak library URIs
        expect(key.debugLabel, isNot(contains('dart:core#')));
      });

      test('returns null for non-InterfaceType', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late void Function() callback;
          }
        ''');

        final DartType functionType = _getFieldType(library, 'Holder', 'callback');

        final BindingKey? key = BindingKey.fromDartType(functionType);

        expect(key, isNull);
      });

      test('returns null for unsupported type argument like Function type', () async {
        final LibraryElement library = await _resolveLibrary('''
          class Holder {
            late List<void Function()> callbacks;
          }
        ''');

        final DartType listOfFunctionType = _getFieldType(library, 'Holder', 'callbacks');

        final BindingKey? key = BindingKey.fromDartType(listOfFunctionType);

        expect(key, isNull);
      });

      group('typeNameOnly', () {
        test('returns bare type name without qualifier suffix', () async {
          final library = await _resolveLibrary('class MyService {}');
          final dartType = _getClassType(library, 'MyService');

          final key = BindingKey.fromDartType(dartType, qualifier: 'prod')!;

          expect(key.typeNameOnly, equals('MyService'));
          expect(key.typeNameOnly, isNot(contains('prod')));
          expect(key.typeNameOnly, isNot(contains('#')));
        });

        test('returns bare type name without qualifier for unqualified key', () async {
          final library = await _resolveLibrary('class Heater {}');
          final dartType = _getClassType(library, 'Heater');

          final key = BindingKey.fromDartType(dartType)!;

          expect(key.typeNameOnly, equals('Heater'));
        });

        test('includes generic type arguments in typeNameOnly', () async {
          final library = await _resolveLibrary('''
            class Holder {
              late List<String> items;
            }
          ''');
          final dartType = _getFieldType(library, 'Holder', 'items');

          final key = BindingKey.fromDartType(dartType)!;

          expect(key.typeNameOnly, contains('List'));
          expect(key.typeNameOnly, contains('String'));
          expect(key.typeNameOnly, isNot(contains('#')));
        });
      });

      group('formattedLabel', () {
        late LibraryElement library;

        setUpAll(() async {
          library = await _resolveLibrary('''
            class Heater {}
            class Repository {}
          ''');
        });

        test('no markers — returns bare type name without parentheses', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Heater'))!;
          expect(key.formattedLabel(), equals('Heater'));
        });

        test('only qualifier — appends @qualifier in parentheses', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Repository'), qualifier: 'brand')!;
          expect(key.formattedLabel(), equals('Repository (@brand)'));
        });

        test('only singleton — appends @singleton in parentheses', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Heater'))!;
          expect(key.formattedLabel(isSingleton: true), equals('Heater (@singleton)'));
        });

        test('only async — appends @async in parentheses', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Heater'))!;
          expect(key.formattedLabel(isAsync: true), equals('Heater (@async)'));
        });

        test('singleton + async — correct order in parentheses', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Heater'))!;
          expect(key.formattedLabel(isSingleton: true, isAsync: true), equals('Heater (@singleton, @async)'));
        });

        test('qualifier + singleton + async — correct order', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Repository'), qualifier: 'brand')!;
          expect(
            key.formattedLabel(isSingleton: true, isAsync: true),
            equals('Repository (@brand, @singleton, @async)'),
          );
        });

        test('with receiver list — appends injected by', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Heater'))!;
          expect(
            key.formattedLabel(receivers: ['Brewer', 'Grinder']),
            equals('Heater (injected by: Brewer, Grinder)'),
          );
        });

        test('qualifier + singleton + async + receivers — full combination, correct order', () {
          final key = BindingKey.fromDartType(_getClassType(library, 'Repository'), qualifier: 'brand')!;
          expect(
            key.formattedLabel(isSingleton: true, isAsync: true, receivers: ['ServiceA', 'ServiceB']),
            equals('Repository (@brand, @singleton, @async, injected by: ServiceA, ServiceB)'),
          );
        });
      });

      test('handles void and dynamic as type arguments', () async {
        final LibraryElement library = await _resolveLibrary('''
          import 'dart:async';
          class Holder {
            late Future<void> futureVoid;
            late List<dynamic> listDynamic;
          }
        ''');

        final DartType futureVoidType = _getFieldType(library, 'Holder', 'futureVoid');
        final DartType listDynamicType = _getFieldType(library, 'Holder', 'listDynamic');

        final BindingKey? keyFutureVoid = BindingKey.fromDartType(futureVoidType);
        final BindingKey? keyListDynamic = BindingKey.fromDartType(listDynamicType);

        expect(keyFutureVoid, isNotNull);
        expect(keyListDynamic, isNotNull);
        expect(keyFutureVoid, isNot(equals(keyListDynamic)));
      });
    });
  });
}
