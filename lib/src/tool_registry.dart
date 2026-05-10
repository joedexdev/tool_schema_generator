import 'tool_exceptions.dart';
import 'tool_result.dart';

/// The signature of every generated tool handler.
///
/// Each handler receives the raw arguments map from the LLM and returns a
/// [Future] that resolves to the tool function's return value.
typedef ToolHandler = Future<dynamic> Function(Map<String, dynamic> args);

/// A registry that maps tool names to their handler functions, providing a
/// clean, type-safe dispatch layer between the LLM and your Dart code.
///
/// Instances are created by the code generator and live in the `.g.dart` file.
/// You should not instantiate this class manually.
///
/// ## Usage
///
/// ```dart
/// // tools.g.dart provides `toolRegistry`
/// import 'tools.dart';
///
/// final result = await toolRegistry.call(
///   toolCall.name,       // e.g. 'getWeather'
///   toolCall.arguments,  // e.g. {'city': 'Cairo', 'unit': 'celsius'}
/// );
///
/// switch (result) {
///   case ToolSuccess(:final value):
///     // Send value back to the model
///   case ToolError(:final code, :final message):
///     // Handle error — optionally send back to the model as feedback
/// }
/// ```
class ToolRegistry {
  final Map<String, ToolHandler> _handlers;

  /// Creates a registry from a map of tool name → handler function.
  ///
  /// This constructor is called by generated code; prefer using the generated
  /// `toolRegistry` constant rather than constructing one manually.
  const ToolRegistry(this._handlers);

  /// Whether a tool with the given [name] is registered.
  bool contains(String name) => _handlers.containsKey(name);

  /// All registered tool names.
  Iterable<String> get toolNames => _handlers.keys;

  /// Invokes the tool registered under [name] with the provided [args] and
  /// returns a [ToolResult].
  ///
  /// **Error handling layers:**
  /// 1. [ToolArgumentException] (invalid/missing arg from LLM) →
  ///    [ToolError] with code `INVALID_ARGUMENT` or `MISSING_ARGUMENT`
  /// 2. Any other exception from the tool's own logic →
  ///    [ToolError] with code `INTERNAL_ERROR`
  ///
  /// Throws [UnknownToolException] if [name] is not registered — this is a
  /// developer/configuration error and is **not** caught internally.
  Future<ToolResult> call(String name, Map<String, dynamic> args) async {
    final handler = _handlers[name];
    if (handler == null) {
      throw UnknownToolException(name, _handlers.keys.toList());
    }

    try {
      // Future.sync wraps both sync and async functions uniformly
      final value = await Future.sync(() => handler(args));
      return ToolSuccess(value);
    } on ToolArgumentException catch (e) {
      final code =
          e.message.toLowerCase().contains('missing')
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
        // Keep the real error out of the LLM context but leave it accessible
        message: 'An internal error occurred while executing tool "$name".',
        actual: e.toString(),
      );
    }
  }

  /// Like [call], but returns `null` instead of throwing [UnknownToolException]
  /// when [name] is not registered.
  ///
  /// Useful in agent loops where optional tools may not be loaded.
  Future<ToolResult>? callOrNull(String name, Map<String, dynamic> args) {
    if (!_handlers.containsKey(name)) return null;
    return call(name, args);
  }
}
