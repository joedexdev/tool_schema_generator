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
  JsonObject format(SchemaFormat format) => _tool.encode(format);

  /// Formats the schema for Google Gemini FunctionDeclaration.
  JsonObject toGemini() => _tool.encode(SchemaFormat.gemini);

  /// Formats the schema for Anthropic Claude.
  JsonObject toAnthropic() => _tool.encode(SchemaFormat.anthropic);

  /// Formats the schema for OpenAI.
  JsonObject toOpenAi() => _tool.encode(SchemaFormat.openAi);

  /// Formats the schema for Model Context Protocol (MCP).
  JsonObject toMcp() => <String, Object?>{
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'inputSchema': parameters,
  };

  /// Raw OpenAI JSON representation.
  JsonObject toJson() => toOpenAi();

  /// Alias for [toJson].
  JsonObject toMap() => toOpenAi();

  @override
  String toString() => 'ToolSchema(name: $name)';
}
