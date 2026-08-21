import 'annotations.dart';
import 'json_types.dart';
import 'tool_definition.dart';

/// Encapsulates a tool's schema and provider formatting methods.
class ToolSchema {
  final ToolDefinition _tool;

  const ToolSchema(this._tool);

  /// Tool wire name.
  String get name => _tool.name;

  /// Tool description.
  String get description => _tool.description;

  /// Provider-agnostic parameters JSON Schema object.
  JsonObject get parameters => _tool.parametersSchema;

  /// Formats the schema for the requested [format].
  ///
  /// The single canonical encoding path:
  ///
  /// ```dart
  /// final gemini = tools.sendEmail.schema.format(.gemini);
  /// ```
  JsonObject format(SchemaFormat format) => _tool.encode(format);

  @override
  String toString() => 'ToolSchema(name: $name)';
}
