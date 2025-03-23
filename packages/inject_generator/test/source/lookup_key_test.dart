import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_visitor.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:inject_generator/src/source/lookup_key.dart';
import 'package:test/test.dart';

void main() {
  group('Type analysis', () {
    test('analyzes class fields', () async {
      final types = await analyzeDartCode('''
        class TestClass {
          List<Map<String, int>> complexField;
          String simpleField;
        }
      ''');

      // Test complex nested type (List<Map<String, int>>)
      final complexType = types['TestClass']?['complexField'];

      // Structure verification
      expect(complexType?.root.symbol, 'List');
      expect(complexType?.typeArguments?.length, 1);
      final mapType = complexType?.typeArguments?[0];
      expect(mapType?.root.symbol, 'Map');
      expect(mapType?.typeArguments?.length, 2);
      expect(mapType?.typeArguments?[0].root.symbol, 'String');
      expect(mapType?.typeArguments?[1].root.symbol, 'int');

      // String representations
      expect(complexType?.toPrettyString(), 'List<Map<String, int>>');
      expect(complexType?.toClassName(), 'ListMapStringInt');

      // Test simple type
      final simpleType = types['TestClass']?['simpleField'];
      expect(simpleType?.root.symbol, 'String');
      expect(simpleType?.typeArguments, isNull);
      expect(simpleType?.toPrettyString(), 'String');
      expect(simpleType?.toClassName(), 'String');
    });

    test('analyzes class fields toFeature conversion', () async {
      final types = await analyzeDartCode('''
        class TestClass {
          List<Map<String, int>> complexField;
          String simpleField;
        }
      ''');

      // Test complex type conversion to Future
      final complexType = types['TestClass']?['complexField'];
      final complexFeature = complexType?.toFeature();
      expect(complexFeature?.root.symbol, 'Future');
      expect(complexFeature?.typeArguments?.length, 1);
      expect(complexFeature?.typeArguments?[0].toPrettyString(), 'List<Map<String, int>>');
      expect(complexFeature?.toPrettyString(), 'Future<List<Map<String, int>>>');
      expect(complexFeature?.toClassName(), 'FutureListMapStringInt');

      // Test simple type conversion to Future
      final simpleType = types['TestClass']?['simpleField'];
      final simpleFeature = simpleType?.toFeature();
      expect(simpleFeature?.root.symbol, 'Future');
      expect(simpleFeature?.typeArguments?.length, 1);
      expect(simpleFeature?.typeArguments?[0].toPrettyString(), 'String');
      expect(simpleFeature?.toPrettyString(), 'Future<String>');
      expect(simpleFeature?.toClassName(), 'FutureString');
    });

    test('analyzes methods with complex types', () async {
      final types = await analyzeDartCode('''
        class TestClass {
          Future<List<Map<String, int>>> getData(Set<DateTime> dates, Map<int, List<bool>> config) {}
        }
      ''');

      // Test return type
      final returnType = types['TestClass']?['getData_return'];
      expect(returnType?.root.symbol, 'Future');
      expect(returnType?.typeArguments?.length, 1);

      final listType = returnType?.typeArguments?[0];
      expect(listType?.root.symbol, 'List');
      expect(listType?.typeArguments?.length, 1);

      final mapType = listType?.typeArguments?[0];
      expect(mapType?.root.symbol, 'Map');
      expect(mapType?.typeArguments?.length, 2);
      expect(mapType?.typeArguments?[0].root.symbol, 'String');
      expect(mapType?.typeArguments?[1].root.symbol, 'int');

      expect(returnType?.toPrettyString(), 'Future<List<Map<String, int>>>');
      expect(returnType?.toClassName(), 'FutureListMapStringInt');

      // Test first parameter
      final datesParam = types['TestClass']?['getData_param_dates'];
      expect(datesParam?.root.symbol, 'Set');
      expect(datesParam?.typeArguments?.length, 1);
      expect(datesParam?.typeArguments?[0].root.symbol, 'DateTime');
      expect(datesParam?.toPrettyString(), 'Set<DateTime>');
      expect(datesParam?.toClassName(), 'SetDateTime');

      // Test second parameter
      final configParam = types['TestClass']?['getData_param_config'];
      expect(configParam?.root.symbol, 'Map');
      expect(configParam?.typeArguments?.length, 2);
      expect(configParam?.typeArguments?[0].root.symbol, 'int');
      expect(configParam?.typeArguments?[1].root.symbol, 'List');
      expect(configParam?.typeArguments?[1].typeArguments?[0].root.symbol, 'bool');
      expect(configParam?.toPrettyString(), 'Map<int, List<bool>>');
      expect(configParam?.toClassName(), 'MapIntListBool');
    });

    test('analyzes constructors with complex types', () async {
      final types = await analyzeDartCode('''
        class TestClass {
          TestClass(List<Set<DateTime>> events);
          TestClass.named(Map<String, Future<List<int>>> data, Set<Map<bool, double>> config);
        }
      ''');

      // Test default constructor parameter
      final eventsParam = types['TestClass']?['_param_events'];
      expect(eventsParam?.root.symbol, 'List');
      expect(eventsParam?.typeArguments?.length, 1);
      expect(eventsParam?.typeArguments?[0].root.symbol, 'Set');
      expect(eventsParam?.typeArguments?[0].typeArguments?[0].root.symbol, 'DateTime');
      expect(eventsParam?.toPrettyString(), 'List<Set<DateTime>>');
      expect(eventsParam?.toClassName(), 'ListSetDateTime');

      // Test named constructor parameters
      final dataParam = types['TestClass']?['named_param_data'];
      expect(dataParam?.root.symbol, 'Map');
      expect(dataParam?.typeArguments?.length, 2);
      expect(dataParam?.typeArguments?[0].root.symbol, 'String');
      expect(dataParam?.typeArguments?[1].root.symbol, 'Future');
      expect(dataParam?.typeArguments?[1].typeArguments?[0].root.symbol, 'List');
      expect(dataParam?.toPrettyString(), 'Map<String, Future<List<int>>>');
      expect(dataParam?.toClassName(), 'MapStringFutureListInt');

      final configParam = types['TestClass']?['named_param_config'];
      expect(configParam?.root.symbol, 'Set');
      expect(configParam?.typeArguments?.length, 1);
      expect(configParam?.typeArguments?[0].root.symbol, 'Map');
      expect(configParam?.typeArguments?[0].typeArguments?[0].root.symbol, 'bool');
      expect(configParam?.typeArguments?[0].typeArguments?[1].root.symbol, 'double');
      expect(configParam?.toPrettyString(), 'Set<Map<bool, double>>');
      expect(configParam?.toClassName(), 'SetMapBoolDouble');
    });

    test('analyzes deeply nested type combinations', () async {
      final types = await analyzeDartCode('''
        class TestClass {
          Future<List<Map<String, Set<int>>>> complexOperation();
        }
      ''');

      final returnType = types['TestClass']?['complexOperation_return'];
      expect(returnType?.root.symbol, 'Future');

      final listType = returnType?.typeArguments?[0];
      expect(listType?.root.symbol, 'List');

      final mapType = listType?.typeArguments?[0];
      expect(mapType?.root.symbol, 'Map');
      expect(mapType?.typeArguments?[0].root.symbol, 'String');
      expect(mapType?.typeArguments?[1].root.symbol, 'Set');

      expect(mapType?.typeArguments?[1].typeArguments?[0].root.symbol, 'int');
      expect(returnType?.toPrettyString(), 'Future<List<Map<String, Set<int>>>>');
      expect(returnType?.toClassName(), 'FutureListMapStringSetInt');
    });

    test('analyzes bounded type parameters', () async {
      final types = await analyzeDartCode('''
        class Container<T extends Comparable<T>> {
          T value;
          List<T> items;
        }
      ''');

      final valueType = types['Container']?['value'];
      final itemsType = types['Container']?['items'];

      expect(valueType?.root.symbol, 'T');
      expect(valueType?.bound?.root.symbol, 'Comparable');
      expect(valueType?.bound?.typeArguments?[0].root.symbol, 'T');

      expect(itemsType?.root.symbol, 'List');
      expect(itemsType?.typeArguments?[0].root.symbol, 'T');
      expect(itemsType?.typeArguments?[0].bound?.root.symbol, 'Comparable');
    });

    test('analyzes multiple bounded type parameters', () async {
      final types = await analyzeDartCode('''
        class Container<K extends Comparable<K>, V extends List<K>> {
          K key;
          V value;
        }
      ''');

      final keyType = types['Container']?['key'];
      expect(keyType?.root.symbol, 'K');
      expect(keyType?.bound?.root.symbol, 'Comparable');
      expect(keyType?.bound?.typeArguments?[0].root.symbol, 'K');

      final valueType = types['Container']?['value'];
      expect(valueType?.root.symbol, 'V');
      expect(valueType?.bound?.root.symbol, 'List');
      expect(valueType?.bound?.typeArguments?[0].root.symbol, 'K');
    });

    test('analyzes interface bounds', () async {
      final types = await analyzeDartCode('''
        class Container<T extends Iterator<String>> {
          T iterator;
        }
      ''');

      final iteratorType = types['Container']?['iterator'];
      expect(iteratorType?.root.symbol, 'T');
      expect(iteratorType?.bound?.root.symbol, 'Iterator');
      expect(iteratorType?.bound?.typeArguments?[0].root.symbol, 'String');
      expect(iteratorType?.toPrettyString(), 'T extends Iterator<String>');
      expect(iteratorType?.bound?.toPrettyString(), 'Iterator<String>');
    });

    test('analyzes class bounds', () async {
      final types = await analyzeDartCode('''
        class Animal {}
        class Container<T extends Animal> {
          T animal;
        }
      ''');

      final animalType = types['Container']?['animal'];
      expect(animalType?.root.symbol, 'T');
      expect(animalType?.bound?.root.symbol, 'Animal');
      expect(animalType?.bound?.typeArguments, isNull);
      expect(animalType?.toPrettyString(), 'T extends Animal');
      expect(animalType?.bound?.toPrettyString(), 'Animal');
    });

    test('analyzes nested bounds', () async {
      final types = await analyzeDartCode('''
        class Container<T extends List<Map<String, T>>> {
          T complex;
        }
      ''');

      final complexType = types['Container']?['complex'];
      expect(complexType?.root.symbol, 'T');
      expect(complexType?.bound?.root.symbol, 'List');

      final mapType = complexType?.bound?.typeArguments?[0];
      expect(mapType?.root.symbol, 'Map');

      expect(mapType?.typeArguments?[0].root.symbol, 'String');
      expect(mapType?.typeArguments?[1].root.symbol, 'T');

      expect(complexType?.toPrettyString(), 'T extends List<Map<String, T>>');
      expect(complexType?.bound?.toPrettyString(), 'List<Map<String, T>>');
    });

    test('analyzes type aliases', () async {
      final types = await analyzeDartCode('''
        typedef JsonMap = Map<String, dynamic>;
        typedef Callback<T> = Future<T> Function(int value);
        
        class TestClass {
          JsonMap data;
          Callback<String> processor;
        }
      ''');

      final jsonMapType = types['TestClass']?['data'];
      expect(jsonMapType?.root.symbol, 'JsonMap');
      expect(jsonMapType?.typeArguments, isNull);

      final callbackType = types['TestClass']?['processor'];
      expect(callbackType?.root.symbol, 'Callback');
      expect(callbackType?.typeArguments, isNull);
    });

    test('throws UnsupportedError for record types', () async {
      await expectLater(
        analyzeDartCode(
          '''
          class Test {
            (int, String) recordField;
          }
        ''',
        ),
        throwsA(
          isA<UnsupportedError>().having((e) => e.message, 'message', contains('Record types are not supported')),
        ),
      );
    });

    test('throws UnsupportedError for function types', () async {
      await expectLater(
        analyzeDartCode(
          '''
          class Test {
            int Function(String) funcField;
          }
        ''',
        ),
        throwsA(
          isA<UnsupportedError>()
              .having((e) => e.message, 'message', contains('Function types cannot be directly used')),
        ),
      );
    });
  });
}

/// Analyzes Dart code and returns a map of member names to their LookupKeys
Future<Map<String, Map<String, LookupKey>>> analyzeDartCode(String code) async {
  // Create an OverlayResourceProvider based on the physical file system.
  final resourceProvider = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);

  // Define a virtual file path for our test Dart file.
  const filePath = '/project/lib/test.dart';

  // Overlay the source code with a modification stamp.
  resourceProvider.setOverlay(
    filePath,
    content: code,
    modificationStamp: 1,
  );

  // Create an AnalysisContextCollection.
  final collection = AnalysisContextCollection(
    includedPaths: [filePath],
    resourceProvider: resourceProvider,
  );

  // Get the analysis context and current session.
  final context = collection.contextFor(filePath);
  final session = context.currentSession;

  // Fully resolve the AST.
  final resolvedUnitResult = await session.getResolvedUnit(filePath) as ResolvedUnitResult;

  // Create a map where the key is the class name and the value is a map of members.
  final result = <String, Map<String, LookupKey>>{};

  // Iterate over all class declarations.
  for (final declaration in resolvedUnitResult.unit.declarations.whereType<ClassDeclaration>()) {
    final classElement = declaration.declaredElement;
    if (classElement == null) {
      continue;
    }
    final className = classElement.name;
    final visitor = TestTypeVisitor();
    final memberMap = <String, LookupKey>{};

    // Process fields.
    for (final field in classElement.fields) {
      memberMap[field.name] = field.type.accept(visitor);
    }
    // Process methods.
    for (final method in classElement.methods) {
      // The return type.
      memberMap['${method.name}_return'] = method.returnType.accept(visitor);
      // And each parameter.
      for (final param in method.parameters) {
        memberMap['${method.name}_param_${param.name}'] = param.type.accept(visitor);
      }
    }
    // Process constructors.
    for (final constructor in classElement.constructors) {
      // Use the constructor name if available (or empty string for unnamed).
      final prefix = constructor.name;
      for (final param in constructor.parameters) {
        memberMap['${prefix}_param_${param.name}'] = param.type.accept(visitor);
      }
    }
    result[className] = memberMap;
  }
  return result;
}

class TestTypeVisitor implements TypeVisitor<LookupKey> {
  @override
  LookupKey visitInterfaceType(InterfaceType type) => LookupKey.fromDartType(type);

  @override
  LookupKey visitDynamicType(DynamicType type) => LookupKey.fromDartType(type);

  @override
  LookupKey visitFunctionType(FunctionType type) => LookupKey.fromDartType(type);

  @override
  LookupKey visitInvalidType(InvalidType type) => LookupKey.fromDartType(type);

  @override
  LookupKey visitNeverType(NeverType type) => LookupKey.fromDartType(type);

  @override
  LookupKey visitRecordType(RecordType type) => LookupKey.fromDartType(type);

  @override
  LookupKey visitTypeParameterType(TypeParameterType type) => LookupKey.fromDartType(type);

  @override
  LookupKey visitVoidType(VoidType type) => LookupKey.fromDartType(type);
}
