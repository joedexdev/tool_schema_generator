import 'dart:collection';
import 'annotations.dart';
import 'json_types.dart';
// One intentional back-reference: the [schema] convenience getter wraps this
// definition in a ToolSchema. Removing it would break public API; every other
// former registry/schema dependency now flows through json_types.dart.
import 'tool_schema.dart';

/// The signature of every generated tool handler.
///
/// Each handler receives the raw arguments map from the LLM and returns a
/// [Future] that resolves to the tool function's return value.
typedef ToolHandler = Future<Object?> Function(JsonObject args);

/// A single tool: its identity, parameter schema, and execution handler.
///
/// Extends [MapView] so it doubles as an OpenAI-compatible [JsonObject]
/// and can be passed directly to APIs that accept `Map<String, Object?>`.
class ToolDefinition extends MapView<String, Object?> {
  /// The tool's wire name.
  final String name;

  /// Human-readable description sent to the model.
  final String description;

  /// Provider-agnostic JSON Schema for the tool's parameters.
  final JsonObject parametersSchema;

  /// The function that executes this tool.
  final ToolHandler handler;

  /// The formats supported by this tool.
  final List<SchemaFormat> formats;

  /// Whether this tool requests strict schema adherence where supported.
  final bool strict;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
    required this.handler,
    this.formats = SchemaFormat.values,
    this.strict = false,
  }) : super({
         'type': 'function',
         'function': {
           'name': name,
           if (description.isNotEmpty) 'description': description,
           'parameters': parametersSchema,
           if (strict) 'strict': true,
         },
       });

  ToolDefinition.raw({
    required JsonObject schema,
    required this.handler,
    this.formats = SchemaFormat.values,
    bool? strict,
  }) : name = extractName(schema),
       description = extractDescription(schema),
       parametersSchema = extractParametersSchema(schema),
       strict = strict ?? extractStrict(schema),
       super(
         schema.containsKey('type') && schema['type'] == 'function'
             ? schema
             : {'type': 'function', 'function': schema},
       );

  static String extractName(JsonObject schema) {
    if (schema['type'] == 'function' && schema['function'] is Map) {
      return (schema['function'] as Map)['name'] as String? ?? '';
    }
    return schema['name'] as String? ?? '';
  }

  static String extractDescription(JsonObject schema) {
    if (schema['type'] == 'function' && schema['function'] is Map) {
      return (schema['function'] as Map)['description'] as String? ?? '';
    }
    return schema['description'] as String? ?? '';
  }

  static JsonObject extractParametersSchema(JsonObject schema) {
    if (schema['type'] == 'function' && schema['function'] is Map) {
      final function = schema['function'] as Map;
      return Map<String, Object?>.from(
        (function['parameters'] as Map?) ?? const {},
      );
    }
    final params = schema['parameters'] ?? schema['input_schema'];
    if (params is Map) {
      return Map<String, Object?>.from(params);
    }
    return const {};
  }

  static bool extractStrict(JsonObject schema) {
    if (schema['type'] == 'function' && schema['function'] is Map) {
      return (schema['function'] as Map)['strict'] == true;
    }
    return schema['strict'] == true;
  }

  /// Dedicated schema wrapper for formatting and parameter inspection.
  ToolSchema get schema => ToolSchema(this);

  /// Invokes the tool handler directly.
  Future<Object?> call(JsonObject args) => handler(args);

  /// Returns the provider-specific schema envelope for [format].
  ///
  /// Every tool supports every format by derivation — there is no
  /// map for a format to be absent from.
  JsonObject encode([SchemaFormat format = SchemaFormat.openAi]) =>
      switch (format) {
        SchemaFormat.openAi => Map<String, Object?>.unmodifiable(this),
        SchemaFormat.anthropic => {
          'name': name,
          if (description.isNotEmpty) 'description': description,
          'input_schema': parametersSchema,
          if (strict) 'strict': true,
        },
        SchemaFormat.gemini => {
          'name': name,
          if (description.isNotEmpty) 'description': description,
          'parameters': parametersSchema,
        },
      };

  /// Formats this tool's schema for Google Gemini.
  JsonObject toGeminiSchema() => encode(SchemaFormat.gemini);

  /// Formats this tool's schema for Anthropic Claude.
  JsonObject toAnthropicSchema() => encode(SchemaFormat.anthropic);

  /// Formats this tool's schema for OpenAI.
  JsonObject toOpenAiSchema() => encode(SchemaFormat.openAi);

  /// Formats this tool's schema for Model Context Protocol (MCP).
  JsonObject toMcpSchema() => <String, Object?>{
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'inputSchema': parametersSchema,
  };
}
