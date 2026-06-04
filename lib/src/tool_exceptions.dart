/// Base class for exceptions raised while dispatching a tool call.
sealed class ToolCallException implements Exception {
  /// Human-readable error description, safe to include in LLM feedback.
  final String message;

  const ToolCallException(this.message);
}

/// Thrown when the supplied arguments omit a required field.
class MissingToolArgumentException extends ToolCallException {
  /// The parameter name that caused the problem.
  final String field;

  const MissingToolArgumentException(this.field, [String? message])
    : super(message ?? 'Missing required argument "$field".');

  @override
  String toString() =>
      'MissingToolArgumentException(field: $field, message: $message)';
}

/// Thrown when an argument exists but does not match the expected shape.
class InvalidToolArgumentException extends ToolCallException {
  /// The parameter name that caused the problem.
  final String field;

  /// The expected type or value, if known.
  final Object? expected;

  /// The actual type or value that was received.
  final Object? actual;

  const InvalidToolArgumentException({
    required this.field,
    required String message,
    this.expected,
    this.actual,
  }) : super(message);

  @override
  String toString() =>
      'InvalidToolArgumentException(field: $field, message: $message)';
}

/// Thrown by `ToolRegistry.call` when no tool with the requested name exists.
class ToolNotFoundException extends ToolCallException {
  /// The name of the tool that was not found.
  final String name;

  /// The names of all currently registered tools.
  final List<String> available;

  ToolNotFoundException(this.name, this.available)
    : super(
        'No tool named "$name". Available tools: [${available.join(', ')}]',
      );

  @override
  String toString() =>
      'ToolNotFoundException(name: $name, available: [${available.join(', ')}])';
}

/// Thrown when the Dart tool function itself throws.
class ToolExecutionException extends ToolCallException {
  /// The name of the tool that failed.
  final String name;

  /// The original exception thrown by the tool.
  final Object error;

  /// The original stack trace, when available.
  final StackTrace stackTrace;

  ToolExecutionException({
    required this.name,
    required this.error,
    required this.stackTrace,
  }) : super('An internal error occurred while executing tool "$name".');

  @override
  String toString() =>
      'ToolExecutionException(name: $name, message: $message, error: $error)';
}
