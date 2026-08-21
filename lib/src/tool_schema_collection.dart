import 'dart:collection';
import 'annotations.dart';
import 'json_types.dart';
import 'tool_definition.dart';
import 'tool_schema.dart';

/// A collection of tool schemas with batch conversion methods for various LLMs.
class ToolSchemaCollection with IterableMixin<ToolSchema> {
  final List<ToolDefinition> _tools;
  final Map<SchemaFormat, List<JsonObject>> _formatCache = {};

  ToolSchemaCollection(Iterable<ToolDefinition> tools)
    : _tools = List.unmodifiable(tools);

  @override
  Iterator<ToolSchema> get iterator =>
      _tools.map<ToolSchema>((ToolDefinition t) => t.schema).iterator;

  @override
  int get length => _tools.length;

  /// Formats all schemas for the given [format].
  ///
  /// Memoized per format: definitions are immutable after construction.
  List<JsonObject> format(SchemaFormat format) => _formatCache.putIfAbsent(
    format,
    () => List.unmodifiable(_tools.map((t) => t.encode(format))),
  );

  /// Formats all schemas for Google Gemini.
  List<JsonObject> toGemini() => format(SchemaFormat.gemini);

  /// Formats all schemas for Anthropic Claude.
  List<JsonObject> toAnthropic() => format(SchemaFormat.anthropic);

  /// Formats all schemas for OpenAI.
  List<JsonObject> toOpenAi() => format(SchemaFormat.openAi);

  /// Formats all schemas for Model Context Protocol (MCP).
  List<JsonObject> toMcp() =>
      List.unmodifiable(_tools.map((t) => t.schema.toMcp()));

  /// Raw OpenAI JSON schema maps.
  List<JsonObject> get raw => toOpenAi();

  @override
  String toString() => 'ToolSchemaCollection(length: $length)';
}
