import 'tool_exceptions.dart';
import 'tool_result.dart';

/// The signature of every generated tool handler.
///
/// Each handler receives the raw arguments map from the LLM and returns a
/// [Future] that resolves to the tool function's return value.
typedef ToolHandler = Future<dynamic> Function(Map<String, dynamic> args);

/// A registry that maps tool names to their handler functions **and** their
/// JSON Schema definitions, providing a unified dispatch + discovery layer
/// between the LLM and your Dart code.
///
/// The generated subclass (from `tool_schema_generator`) extends this class
/// and adds a strongly-typed getter per tool:
///
/// ```dart
/// // Generated in tools.g.dart — do not write this manually
/// final toolRegistry = _ToolRegistry({ handlers }, { schemas });
/// ```
///
/// ## Usage
///
/// ```dart
/// import 'tools.dart'; // exposes `toolRegistry`
///
/// // ── Build the LLM request ─────────────────────────────────
/// llm.generate(tools: toolRegistry.allSchemas);
///
/// // ── Or select specific tool schemas by Dart name ──────────
/// llm.generate(tools: [toolRegistry.getWeather]);  // generated getter
///
/// // ── Handle the response ───────────────────────────────────
/// final result = await toolRegistry.call(call.name, call.arguments);
/// switch (result) {
///   case ToolSuccess(:final value): sendToModel(value.toString());
///   case ToolError(:final code, :final message): print('$code: $message');
/// }
/// ```
class ToolRegistry {
  final Map<String, ToolHandler> _handlers;
  final Map<String, Map<String, dynamic>> _schemas;

  /// Creates a registry.
  ///
  /// [handlers] maps every tool name to its handler function.
  /// [schemas] maps every tool name to its JSON Schema definition. When
  /// omitted, [allSchemas] will be empty and [schemaFor] will throw.
  const ToolRegistry(this._handlers, [this._schemas = const {}]);

  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Whether a tool with the given [name] is registered.
  bool contains(String name) => _handlers.containsKey(name);

  /// All registered tool names.
  Iterable<String> get toolNames => _handlers.keys;

  /// Returns an unmodifiable list of all registered tool schemas.
  ///
  /// Pass this directly to your LLM client instead of maintaining a separate
  /// `allToolSchemas` list:
  ///
  /// ```dart
  /// await llm.generate(tools: toolRegistry.allSchemas);
  /// ```
  List<Map<String, dynamic>> get allSchemas =>
      List.unmodifiable(_schemas.values);

  /// Returns the JSON Schema for the tool registered under [name].
  ///
  /// Throws [StateError] if no schema has been registered for [name].
  /// Prefer the generated named getters (e.g. `toolRegistry.getWeather`)
  /// over this method when you know the tool name at compile time.
  Map<String, dynamic> schemaFor(String name) =>
      _schemas[name] ??
      (throw StateError(
        'No schema registered for tool "$name". '
        'Available: [${_schemas.keys.join(', ')}]',
      ));

  // ── Dispatch ──────────────────────────────────────────────────────────────

  /// Invokes the tool registered under [name] with the provided [args] and
  /// returns a [ToolResult].
  ///
  /// **Error handling layers:**
  /// 1. [ToolArgumentException] → [ToolError] with code `INVALID_ARGUMENT` / `MISSING_ARGUMENT`
  /// 2. Any other exception → [ToolError] with code `INTERNAL_ERROR`
  ///
  /// Throws [UnknownToolException] if [name] is not registered.
  Future<ToolResult> call(String name, Map<String, dynamic> args) async {
    final handler = _handlers[name];
    if (handler == null) {
      throw UnknownToolException(name, _handlers.keys.toList());
    }

    try {
      final value = await Future.sync(() => handler(args));
      return ToolSuccess(value);
    } on ToolArgumentException catch (e) {
      final code = e.message.toLowerCase().contains('missing')
          ? 'MISSING_ARGUMENT'
          : 'INVALID_ARGUMENT';
      return ToolError(
        code: code,
        message: e.message,
        field: e.field,
        expected: e.expected,
        actual: e.actual,
      );
    } catch (e) {
      return ToolError(
        code: 'INTERNAL_ERROR',
        message: 'An internal error occurred while executing tool "$name".',
        actual: e.toString(),
      );
    }
  }

  /// Like [call], but returns `null` instead of throwing [UnknownToolException]
  /// when [name] is not registered.
  Future<ToolResult>? callOrNull(String name, Map<String, dynamic> args) {
    if (!_handlers.containsKey(name)) return null;
    return call(name, args);
  }
}
