import 'dart_source.dart';

/// Internal JSON Schema representation used by the generator.
///
/// These objects keep schema analysis separate from Dart source rendering.
sealed class SchemaSpec {
  const SchemaSpec({this.description, this.isNullable = false});

  final String? description;
  final bool isNullable;

  SchemaSpec copyWith({String? description, bool? isNullable});

  SchemaSpec withDescription(String description) =>
      copyWith(description: description);

  SchemaSpec toStrict();

  String toDartSource({bool useNullUnion = false});

  String renderEntries(List<String> entries, {required bool useNullUnion}) {
    final allEntries = <String>[
      if (description != null)
        "'description': ${dartStringLiteral(description!)}",
      if (isNullable && !useNullUnion) "'nullable': true",
      ...entries,
    ];
    return '<String, Object?>{${allEntries.join(', ')}}';
  }

  String typeEntry(String type, {required bool useNullUnion}) {
    if (isNullable && useNullUnion) {
      return "'type': <String>['$type', 'null']";
    }
    return "'type': '$type'";
  }
}

final class StringSchemaSpec extends SchemaSpec {
  const StringSchemaSpec({super.description, super.isNullable});

  @override
  StringSchemaSpec copyWith({String? description, bool? isNullable}) =>
      StringSchemaSpec(
        description: description ?? this.description,
        isNullable: isNullable ?? this.isNullable,
      );

  @override
  StringSchemaSpec toStrict() => this;

  @override
  String toDartSource({bool useNullUnion = false}) => renderEntries([
    typeEntry('string', useNullUnion: useNullUnion),
  ], useNullUnion: useNullUnion);
}

final class IntegerSchemaSpec extends SchemaSpec {
  const IntegerSchemaSpec({super.description, super.isNullable});

  @override
  IntegerSchemaSpec copyWith({String? description, bool? isNullable}) =>
      IntegerSchemaSpec(
        description: description ?? this.description,
        isNullable: isNullable ?? this.isNullable,
      );

  @override
  IntegerSchemaSpec toStrict() => this;

  @override
  String toDartSource({bool useNullUnion = false}) => renderEntries([
    typeEntry('integer', useNullUnion: useNullUnion),
  ], useNullUnion: useNullUnion);
}

final class NumberSchemaSpec extends SchemaSpec {
  const NumberSchemaSpec({super.description, super.isNullable});

  @override
  NumberSchemaSpec copyWith({String? description, bool? isNullable}) =>
      NumberSchemaSpec(
        description: description ?? this.description,
        isNullable: isNullable ?? this.isNullable,
      );

  @override
  NumberSchemaSpec toStrict() => this;

  @override
  String toDartSource({bool useNullUnion = false}) => renderEntries([
    typeEntry('number', useNullUnion: useNullUnion),
  ], useNullUnion: useNullUnion);
}

final class BooleanSchemaSpec extends SchemaSpec {
  const BooleanSchemaSpec({super.description, super.isNullable});

  @override
  BooleanSchemaSpec copyWith({String? description, bool? isNullable}) =>
      BooleanSchemaSpec(
        description: description ?? this.description,
        isNullable: isNullable ?? this.isNullable,
      );

  @override
  BooleanSchemaSpec toStrict() => this;

  @override
  String toDartSource({bool useNullUnion = false}) => renderEntries([
    typeEntry('boolean', useNullUnion: useNullUnion),
  ], useNullUnion: useNullUnion);
}

final class ArraySchemaSpec extends SchemaSpec {
  const ArraySchemaSpec({
    required this.items,
    super.description,
    super.isNullable,
  });

  final SchemaSpec? items;

  @override
  ArraySchemaSpec copyWith({
    SchemaSpec? items,
    String? description,
    bool? isNullable,
  }) => ArraySchemaSpec(
    items: items ?? this.items,
    description: description ?? this.description,
    isNullable: isNullable ?? this.isNullable,
  );

  @override
  ArraySchemaSpec toStrict() => copyWith(items: items?.toStrict());

  @override
  String toDartSource({bool useNullUnion = false}) => renderEntries([
    typeEntry('array', useNullUnion: useNullUnion),
    if (items != null)
      "'items': ${items!.toDartSource(useNullUnion: useNullUnion)}",
  ], useNullUnion: useNullUnion);
}

final class ObjectSchemaSpec extends SchemaSpec {
  const ObjectSchemaSpec({
    this.properties = const {},
    this.required = const [],
    this.additionalProperties,
    super.description,
    super.isNullable,
  });

  final Map<String, SchemaSpec> properties;
  final List<String> required;
  final bool? additionalProperties;

  @override
  ObjectSchemaSpec copyWith({
    Map<String, SchemaSpec>? properties,
    List<String>? required,
    bool? additionalProperties,
    String? description,
    bool? isNullable,
  }) => ObjectSchemaSpec(
    properties: properties ?? this.properties,
    required: required ?? this.required,
    additionalProperties: additionalProperties ?? this.additionalProperties,
    description: description ?? this.description,
    isNullable: isNullable ?? this.isNullable,
  );

  @override
  ObjectSchemaSpec toStrict() => copyWith(
    properties: properties.map((name, spec) => MapEntry(name, spec.toStrict())),
    required: properties.keys.toList(),
    additionalProperties: false,
  );

  @override
  String toDartSource({bool useNullUnion = false}) {
    final entries = <String>[typeEntry('object', useNullUnion: useNullUnion)];
    if (properties.isNotEmpty) {
      final propertyEntries = properties.entries
          .map(
            (entry) =>
                '${dartStringLiteral(entry.key)}: ${entry.value.toDartSource(useNullUnion: useNullUnion)}',
          )
          .join(', ');
      entries.add("'properties': <String, Object?>{$propertyEntries}");
    }
    if (required.isNotEmpty) {
      final requiredItems = required.map(dartStringLiteral).join(', ');
      entries.add("'required': <String>[$requiredItems]");
    }
    if (additionalProperties != null) {
      entries.add("'additionalProperties': $additionalProperties");
    }
    return renderEntries(entries, useNullUnion: useNullUnion);
  }
}

final class EnumSchemaSpec extends SchemaSpec {
  const EnumSchemaSpec({
    required this.values,
    super.description,
    super.isNullable,
  });

  final List<String> values;

  @override
  EnumSchemaSpec copyWith({
    List<String>? values,
    String? description,
    bool? isNullable,
  }) => EnumSchemaSpec(
    values: values ?? this.values,
    description: description ?? this.description,
    isNullable: isNullable ?? this.isNullable,
  );

  @override
  EnumSchemaSpec toStrict() => this;

  @override
  String toDartSource({bool useNullUnion = false}) {
    final enumValues = values.map(dartStringLiteral).join(', ');
    return renderEntries([
      typeEntry('string', useNullUnion: useNullUnion),
      "'enum': <String>[$enumValues]",
    ], useNullUnion: useNullUnion);
  }
}
