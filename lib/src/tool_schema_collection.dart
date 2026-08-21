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
  /// The single canonical batch encoding path:
  ///
  /// ```dart
  /// llm.generate(tools: tools.schemas.format(.gemini));
  /// ```
  ///
  /// Memoized per format: definitions are immutable after construction.
  List<JsonObject> format(SchemaFormat format) => _formatCache.putIfAbsent(
    format,
    () => List.unmodifiable(_tools.map((t) => t.encode(format))),
  );

  @override
  String toString() => 'ToolSchemaCollection(length: $length)';
}
