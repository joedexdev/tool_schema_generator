import 'package:analyzer/dart/element/element.dart';
import 'package:tool_schema_generator/tool_schema_generator.dart';

import 'schema_spec.dart';

final class ToolSpec {
  const ToolSpec({
    required this.element,
    required this.name,
    required this.description,
    required this.formats,
    required this.parameters,
    required this.parametersSchema,
    required this.strict,
  });

  final TopLevelFunctionElement element;
  final String name;
  final String description;
  final List<SchemaFormat> formats;
  final List<ParameterSpec> parameters;
  final ObjectSchemaSpec parametersSchema;
  final bool strict;
}

final class ParameterSpec {
  const ParameterSpec({
    required this.element,
    required this.name,
    required this.isRequired,
    required this.isNamed,
    required this.isInjected,
    required this.defaultValueCode,
    required this.schema,
  });

  final FormalParameterElement element;
  final String name;
  final bool isRequired;
  final bool isNamed;
  final bool isInjected;
  final String? defaultValueCode;
  final SchemaSpec schema;
}
