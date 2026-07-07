import 'package:test/test.dart';
import 'package:tool_schema_generator/src/schema_spec.dart';

void main() {
  group('SchemaSpec rendering', () {
    test('keeps nullable keyword for non-strict schemas', () {
      expect(
        const StringSchemaSpec(isNullable: true).toDartSource(),
        "<String, Object?>{'nullable': true, 'type': 'string'}",
      );
    });

    test('uses null unions for strict nullable primitive schemas', () {
      expect(
        const StringSchemaSpec(
          isNullable: true,
        ).toDartSource(useNullUnion: true),
        "<String, Object?>{'type': <String>['string', 'null']}",
      );
      expect(
        const IntegerSchemaSpec(
          isNullable: true,
        ).toDartSource(useNullUnion: true),
        "<String, Object?>{'type': <String>['integer', 'null']}",
      );
      expect(
        const NumberSchemaSpec(
          isNullable: true,
        ).toDartSource(useNullUnion: true),
        "<String, Object?>{'type': <String>['number', 'null']}",
      );
      expect(
        const BooleanSchemaSpec(
          isNullable: true,
        ).toDartSource(useNullUnion: true),
        "<String, Object?>{'type': <String>['boolean', 'null']}",
      );
    });

    test('uses null unions for arrays and nested nullable items', () {
      final source = const ArraySchemaSpec(
        items: StringSchemaSpec(isNullable: true),
        isNullable: true,
      ).toDartSource(useNullUnion: true);

      expect(source, contains("'type': <String>['array', 'null']"));
      expect(source, contains("'items': <String, Object?>{"));
      expect(source, contains("'type': <String>['string', 'null']"));
      expect(source, isNot(contains("'nullable': true")));
    });

    test('uses null unions for nullable object schemas', () {
      final source = const ObjectSchemaSpec(
        properties: {'note': StringSchemaSpec(isNullable: true)},
        required: ['note'],
        additionalProperties: false,
        isNullable: true,
      ).toDartSource(useNullUnion: true);

      expect(source, contains("'type': <String>['object', 'null']"));
      expect(source, contains("'note': <String, Object?>{"));
      expect(source, contains("'type': <String>['string', 'null']"));
      expect(source, contains("'additionalProperties': false"));
      expect(source, isNot(contains("'nullable': true")));
    });

    test('keeps enum values unchanged while using null union type', () {
      final source = const EnumSchemaSpec(
        values: ['low', 'high'],
        isNullable: true,
      ).toDartSource(useNullUnion: true);

      expect(source, contains("'type': <String>['string', 'null']"));
      expect(source, contains("'enum': <String>['low', 'high']"));
      expect(
        source,
        isNot(contains("'enum': <String>['low', 'high', 'null']")),
      );
    });

    test(
      'escapes descriptions, property names, required names, and enum values',
      () {
        final objectSource = const ObjectSchemaSpec(
          description: r'Cost is $5',
          properties: {
            r'cost$key': StringSchemaSpec(description: r'Use $query'),
          },
          required: [r'cost$key'],
        ).toDartSource();

        expect(objectSource, contains(r"'description': 'Cost is \$5'"));
        expect(objectSource, contains(r"'cost\$key': <String, Object?>{"));
        expect(objectSource, contains(r"'description': 'Use \$query'"));
        expect(objectSource, contains(r"'required': <String>['cost\$key']"));

        final enumSource = const EnumSchemaSpec(
          values: [r'low$cost', "owner's"],
        ).toDartSource();

        expect(enumSource, contains(r"'low\$cost'"));
        expect(enumSource, contains(r"'owner\'s'"));
      },
    );
  });
}
