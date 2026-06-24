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

  String toDartSource();

  String renderEntries(List<String> entries) {
    final allEntries = <String>[
      if (description != null)
        "'description': '${_escapeString(description!)}'",
      if (isNullable) "'nullable': true",
      ...entries,
    ];
    return '<String, Object?>{${allEntries.join(', ')}}';
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
  String toDartSource() => renderEntries(["'type': 'string'"]);
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
  String toDartSource() => renderEntries(["'type': 'integer'"]);
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
  String toDartSource() => renderEntries(["'type': 'number'"]);
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
  String toDartSource() => renderEntries(["'type': 'boolean'"]);
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
  String toDartSource() => renderEntries([
    "'type': 'array'",
    if (items != null) "'items': ${items!.toDartSource()}",
  ]);
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
  String toDartSource() {
    final entries = <String>["'type': 'object'"];
    if (properties.isNotEmpty) {
      final propertyEntries = properties.entries
          .map(
            (entry) =>
                "'${_escapeString(entry.key)}': ${entry.value.toDartSource()}",
          )
          .join(', ');
      entries.add("'properties': <String, Object?>{$propertyEntries}");
    }
    if (required.isNotEmpty) {
      final requiredItems = required
          .map((name) => "'${_escapeString(name)}'")
          .join(', ');
      entries.add("'required': <String>[$requiredItems]");
    }
    if (additionalProperties != null) {
      entries.add("'additionalProperties': $additionalProperties");
    }
    return renderEntries(entries);
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
  String toDartSource() {
    final enumValues = values
        .map((value) => "'${_escapeString(value)}'")
        .join(', ');
    return renderEntries(["'type': 'string'", "'enum': <String>[$enumValues]"]);
  }
}

String _escapeString(String input) {
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n');
}
