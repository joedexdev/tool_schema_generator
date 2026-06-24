import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

import 'package:tool_schema_generator/src/schema_spec.dart';
import 'package:tool_schema_generator/src/type_mapper.dart';

void main() {
  group('TypeMapper', () {
    group('primitive types', () {
      test('maps String to "string"', () async {
        final result = await _resolveAndMapType('String param');
        expect(result, contains("'type': 'string'"));
        expect(result, isNot(contains("'nullable'")));
      });

      test('maps int to "integer"', () async {
        final result = await _resolveAndMapType('int param');
        expect(result, contains("'type': 'integer'"));
      });

      test('maps double to "number"', () async {
        final result = await _resolveAndMapType('double param');
        expect(result, contains("'type': 'number'"));
      });

      test('maps num to "number"', () async {
        final result = await _resolveAndMapType('num param');
        expect(result, contains("'type': 'number'"));
      });

      test('maps bool to "boolean"', () async {
        final result = await _resolveAndMapType('bool param');
        expect(result, contains("'type': 'boolean'"));
      });
    });

    group('nullable types', () {
      test('maps String? with nullable flag', () async {
        final result = await _resolveAndMapType('String? param');
        expect(result, contains("'nullable': true"));
        expect(result, contains("'type': 'string'"));
      });

      test('maps int? with nullable flag', () async {
        final result = await _resolveAndMapType('int? param');
        expect(result, contains("'nullable': true"));
        expect(result, contains("'type': 'integer'"));
      });

      test('maps bool? with nullable flag', () async {
        final result = await _resolveAndMapType('bool? param');
        expect(result, contains("'nullable': true"));
        expect(result, contains("'type': 'boolean'"));
      });
    });

    group('collection types', () {
      test('maps List<String> to array with string items', () async {
        final result = await _resolveAndMapType('List<String> param');
        expect(result, contains("'type': 'array'"));
        expect(result, contains("'items':"));
        expect(result, contains("'type': 'string'"));
      });

      test('maps List<int> to array with integer items', () async {
        final result = await _resolveAndMapType('List<int> param');
        expect(result, contains("'type': 'array'"));
        expect(result, contains("'type': 'integer'"));
      });

      test('maps List<String>? with nullable flag', () async {
        final result = await _resolveAndMapType('List<String>? param');
        expect(result, contains("'nullable': true"));
        expect(result, contains("'type': 'array'"));
      });

      test('maps Map<String, dynamic> to object', () async {
        final result = await _resolveAndMapType('Map<String, dynamic> param');
        expect(result, contains("'type': 'object'"));
      });
    });

    group('enum types', () {
      test('maps enum to string with enum values', () async {
        final result = await _resolveAndMapEnum();
        expect(result, contains("'type': 'string'"));
        expect(result, contains("'enum':"));
        expect(result, contains("'red'"));
        expect(result, contains("'green'"));
        expect(result, contains("'blue'"));
      });
    });

    group('nested class types', () {
      test('maps class to object with properties and required', () async {
        final result = await _resolveAndMapClass();
        expect(result, contains("'type': 'object'"));
        expect(result, contains("'properties':"));
        expect(result, contains("'x':"));
        expect(result, contains("'y':"));
        expect(result, contains("'type': 'number'"));
        expect(result, contains("'required':"));
      });

      test('maps class with only required params', () async {
        final result = await _resolveAndMapClassWithRequiredOnly();
        expect(result, contains("'type': 'object'"));
        expect(result, contains("'properties':"));
        expect(result, contains("'name':"));
        expect(result, contains("'required':"));
        expect(result, contains("'name'"));
      });
    });

    group('void and dynamic types', () {
      test('maps void to string fallback', () async {
        final result = await _resolveAndMapReturnType('void');
        expect(result, contains("'type': 'string'"));
      });

      test('maps dynamic to string fallback', () async {
        final result = await _resolveAndMapType('dynamic param');
        expect(result, contains("'type': 'string'"));
      });
    });
  });
}

/// Helper: resolves a Dart source with a function parameter of the given type,
/// then maps the first parameter's type using [TypeMapper].
Future<String> _resolveAndMapType(String paramDeclaration) async {
  final mapper = TypeMapper();
  late SchemaSpec result;

  await resolveSource(
    '''
    library test_lib;
    void testFn($paramDeclaration) {}
    ''',
    (resolver) async {
      final lib = await resolver.findLibraryByName('test_lib');
      final fn = lib!.topLevelFunctions.firstWhere((f) => f.name == 'testFn');
      result = mapper.mapType(fn.formalParameters.first.type);
    },
    inputId: makeAssetId('_test|lib/test.dart'),
  );

  return result.toDartSource();
}

/// Helper: resolves a return type and maps it.
Future<String> _resolveAndMapReturnType(String returnType) async {
  final mapper = TypeMapper();
  late SchemaSpec result;

  await resolveSource(
    '''
    library test_lib;
    $returnType testFn() {}
    ''',
    (resolver) async {
      final lib = await resolver.findLibraryByName('test_lib');
      final fn = lib!.topLevelFunctions.firstWhere((f) => f.name == 'testFn');
      result = mapper.mapType(fn.returnType);
    },
    inputId: makeAssetId('_test|lib/test.dart'),
  );

  return result.toDartSource();
}

/// Helper: resolves an enum type and maps it.
Future<String> _resolveAndMapEnum() async {
  final mapper = TypeMapper();
  late SchemaSpec result;

  await resolveSource(
    '''
    library test_lib;
    enum Color { red, green, blue }
    void testFn(Color param) {}
    ''',
    (resolver) async {
      final lib = await resolver.findLibraryByName('test_lib');
      final fn = lib!.topLevelFunctions.firstWhere((f) => f.name == 'testFn');
      result = mapper.mapType(fn.formalParameters.first.type);
    },
    inputId: makeAssetId('_test|lib/test.dart'),
  );

  return result.toDartSource();
}

/// Helper: resolves a class type with required constructor params.
Future<String> _resolveAndMapClass() async {
  final mapper = TypeMapper();
  late SchemaSpec result;

  await resolveSource(
    '''
    library test_lib;
    class Point {
      final double x;
      final double y;
      const Point({required this.x, required this.y});
    }
    void testFn(Point param) {}
    ''',
    (resolver) async {
      final lib = await resolver.findLibraryByName('test_lib');
      final fn = lib!.topLevelFunctions.firstWhere((f) => f.name == 'testFn');
      result = mapper.mapType(fn.formalParameters.first.type);
    },
    inputId: makeAssetId('_test|lib/test.dart'),
  );

  return result.toDartSource();
}

/// Helper: resolves a class with required-only constructor params.
Future<String> _resolveAndMapClassWithRequiredOnly() async {
  final mapper = TypeMapper();
  late SchemaSpec result;

  await resolveSource(
    '''
    library test_lib;
    class Person {
      final String name;
      const Person({required this.name});
    }
    void testFn(Person param) {}
    ''',
    (resolver) async {
      final lib = await resolver.findLibraryByName('test_lib');
      final fn = lib!.topLevelFunctions.firstWhere((f) => f.name == 'testFn');
      result = mapper.mapType(fn.formalParameters.first.type);
    },
    inputId: makeAssetId('_test|lib/test.dart'),
  );

  return result.toDartSource();
}
