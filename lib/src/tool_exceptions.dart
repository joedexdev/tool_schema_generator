/// Thrown internally by the generated dispatcher when the arguments map
/// supplied by the LLM contains a field with the wrong type or is missing
/// a required field.
///
/// This exception is caught at the [ToolRegistry] boundary and converted into
/// a structured [ToolError] with code `INVALID_ARGUMENT` or `MISSING_ARGUMENT`.
/// It should **not** propagate to application code.
class ToolArgumentException implements Exception {
  /// The parameter name that caused the problem.
  final String field;

  /// A description of what went wrong (e.g. "expected String, got int").
  final String message;

  /// The expected type or value, if known.
  final dynamic expected;

  /// The actual type or value that was received.
  final dynamic actual;

  const ToolArgumentException({
    required this.field,
    required this.message,
    this.expected,
    this.actual,
  });

  @override
  String toString() =>
      'ToolArgumentException(field: $field, message: $message)';
}

/// Thrown by [ToolRegistry.call] when no tool with the requested name has
/// been registered.
///
/// Unlike [ToolArgumentException], this is **not** caught inside the registry —
/// it propagates to the caller so that framework code can handle misconfigured
/// registries explicitly.
class UnknownToolException implements Exception {
  /// The name of the tool that was not found.
  final String name;

  /// The names of all currently registered tools.
  final List<String> available;

  const UnknownToolException(this.name, this.available);

  @override
  String toString() =>
      'UnknownToolException: No tool named "$name". '
      'Available tools: [${available.join(', ')}]';
}
