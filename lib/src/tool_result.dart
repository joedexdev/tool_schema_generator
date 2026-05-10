/// The result of invoking a tool through [ToolRegistry].
///
/// This is a sealed class with two variants:
/// - [ToolSuccess] — the tool ran successfully
/// - [ToolError]   — the tool failed with a structured, machine-readable error
///
/// Example:
/// ```dart
/// final result = await toolRegistry.call('getWeather', {'city': 'Cairo'});
/// switch (result) {
///   case ToolSuccess(:final value): print('Result: $value');
///   case ToolError(:final code, :final message): print('$code: $message');
/// }
/// ```
sealed class ToolResult {
  const ToolResult();
}

/// Indicates a tool ran successfully.
///
/// [value] contains the raw return value of the Dart function, which may be
/// any type (`String`, `int`, custom objects, etc.).
final class ToolSuccess extends ToolResult {
  /// The raw return value from the invoked Dart function.
  final dynamic value;

  const ToolSuccess(this.value);

  @override
  String toString() => 'ToolSuccess($value)';
}

/// Indicates a tool invocation failed.
///
/// Errors are categorised by [code]:
///
/// | Code | Meaning |
/// |---|---|
/// | `UNKNOWN_TOOL` | No tool with the requested name is registered |
/// | `INVALID_ARGUMENT` | The model sent a wrong type for a parameter |
/// | `MISSING_ARGUMENT` | A required parameter was absent from the args map |
/// | `INTERNAL_ERROR` | An unexpected exception occurred inside the tool function |
final class ToolError extends ToolResult {
  /// Machine-readable error category. See the class documentation for values.
  final String code;

  /// Human-readable error description, safe to include in LLM feedback.
  final String message;

  /// The parameter name that caused the error, if applicable.
  final String? field;

  /// The type or value that was expected, if applicable.
  final dynamic expected;

  /// The type or value that was actually received, if applicable.
  final dynamic actual;

  const ToolError({
    required this.code,
    required this.message,
    this.field,
    this.expected,
    this.actual,
  });

  @override
  String toString() =>
      'ToolError(code: $code, message: $message'
      '${field != null ? ', field: $field' : ''})';
}
