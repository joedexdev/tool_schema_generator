import 'tool_exceptions.dart';
import 'annotations.dart';

/// A JSON object passed to or produced by tool schema APIs.
typedef JsonObject = Map<String, Object?>;

/// A JSON array passed to or produced by tool schema APIs.
typedef JsonArray = List<Object?>;

/// The signature of every generated tool handler.
///
/// Each handler receives the raw arguments map from the LLM and returns a
/// [Future] that resolves to the tool function's return value.
typedef ToolHandler = Future<Object?> Function(JsonObject args);

/// A registry that maps tool names to their handler functions **and** their
/// provider-shaped schema definitions, providing a unified dispatch + discovery layer
/// between the LLM and your Dart code.
///
/// The generated subclass (from `tool_schema_generator`) extends this class
/// and adds a strongly-typed getter per tool:
///
/// ```dart
/// // Generated in tools.g.dart — do not write this manually
/// final toolRegistry = _ToolRegistry({ handlers }, { schemasByFlavor });
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
/// final value = await toolRegistry.call(call.name, call.arguments);
/// sendToModel(value.toString());
/// ```
class ToolRegistry {
  final Map<String, ToolHandler> _handlers;
  final Map<SchemaFlavor, Map<String, JsonObject>> _schemas;

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
  List<JsonObject> get allSchemas => schemasFor(SchemaFlavor.openAi);

  /// Returns all schemas generated for [flavor].
  List<JsonObject> schemasFor(SchemaFlavor flavor) =>
      List.unmodifiable(_schemas[flavor]?.values ?? const []);

  /// Returns the JSON Schema for the tool registered under [name].
  ///
  /// Throws [StateError] if no schema has been registered for [name].
  /// Prefer the generated named getters (e.g. `toolRegistry.getWeather`)
  /// over this method when you know the tool name at compile time.
  JsonObject schemaFor(
    String name, [
    SchemaFlavor flavor = SchemaFlavor.openAi,
  ]) =>
      _schemas[flavor]?[name] ??
      (throw StateError(
        'No ${flavor.name} schema registered for tool "$name". '
        'Available: [${_schemas[flavor]?.keys.join(', ') ?? ''}]',
      ));

  // ── Dispatch ──────────────────────────────────────────────────────────────

  /// Invokes the tool registered under [name] with the provided [args] and
  /// returns the raw Dart function value.
  ///
  /// Throws [ToolNotFoundException], [MissingToolArgumentException],
  /// [InvalidToolArgumentException], or [ToolExecutionException].
  Future<Object?> call(String name, JsonObject args) async {
    final handler = _handlers[name];
    if (handler == null) {
      throw ToolNotFoundException(name, _handlers.keys.toList());
    }

    try {
      return await Future.sync(() => handler(args));
    } on ToolCallException {
      rethrow;
    } catch (e, stackTrace) {
      throw ToolExecutionException(
        name: name,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Like [call], but returns `null` instead of throwing [ToolNotFoundException]
  /// when [name] is not registered.
  Future<Object?>? callOrNull(String name, JsonObject args) {
    if (!_handlers.containsKey(name)) return null;
    return call(name, args);
  }

  /// Returns a required argument with type validation.
  static T getRequiredArg<T>(JsonObject args, String field) {
    if (!args.containsKey(field)) {
      throw MissingToolArgumentException(field);
    }

    final value = args[field];
    if (value is! T) {
      throw InvalidToolArgumentException(
        field: field,
        message: 'Expected type $T, got ${value.runtimeType}.',
        expected: T,
        actual: value,
      );
    }
    return value;
  }

  /// Returns an optional argument with type validation.
  static T? getOptionalArg<T>(JsonObject args, String field) {
    if (!args.containsKey(field) || args[field] == null) return null;

    final value = args[field];
    if (value is! T) {
      throw InvalidToolArgumentException(
        field: field,
        message: 'Expected type $T, got ${value.runtimeType}.',
        expected: T,
        actual: value,
      );
    }
    return value;
  }

  /// Returns an argument or [defaultValue] when the field is absent or null.
  static T getArgOrDefault<T>(JsonObject args, String field, T defaultValue) =>
      getOptionalArg<T>(args, field) ?? defaultValue;

  /// Returns a required numeric argument as a [double].
  static double getRequiredDoubleArg(JsonObject args, String field) =>
      getRequiredArg<num>(args, field).toDouble();

  /// Returns an optional numeric argument as a [double].
  static double? getOptionalDoubleArg(JsonObject args, String field) =>
      getOptionalArg<num>(args, field)?.toDouble();

  /// Returns a required JSON object argument.
  static JsonObject getRequiredObjectArg(JsonObject args, String field) {
    final value = getRequiredArg<Object?>(args, field);
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      try {
        return Map<String, Object?>.from(value);
      } catch (_) {
        // Fall through to a clearer package exception below.
      }
    }
    throw InvalidToolArgumentException(
      field: field,
      message: 'Expected type JsonObject, got ${value.runtimeType}.',
      expected: JsonObject,
      actual: value,
    );
  }

  /// Returns an optional JSON object argument.
  static JsonObject? getOptionalObjectArg(JsonObject args, String field) {
    if (!args.containsKey(field) || args[field] == null) return null;
    return getRequiredObjectArg(args, field);
  }

  /// Returns an optional list argument with item type validation.
  static List<T>? getOptionalListArg<T>(JsonObject args, String field) {
    if (!args.containsKey(field) || args[field] == null) return null;

    final value = args[field];
    if (value is List) {
      return _castList<T>(field, value);
    }

    throw InvalidToolArgumentException(
      field: field,
      message: 'Expected type List, got ${value.runtimeType}.',
      expected: List,
      actual: value,
    );
  }

  /// Returns a required list argument with item type validation.
  static List<T> getRequiredListArg<T>(JsonObject args, String field) {
    if (!args.containsKey(field)) {
      throw MissingToolArgumentException(field);
    }

    final value = args[field];
    if (value is List) {
      return _castList<T>(field, value);
    }

    throw InvalidToolArgumentException(
      field: field,
      message: 'Expected type List, got ${value.runtimeType}.',
      expected: List,
      actual: value,
    );
  }

  static List<T> _castList<T>(String field, List value) {
    final result = <T>[];
    for (final item in value) {
      if (item is! T) {
        throw InvalidToolArgumentException(
          field: field,
          message: 'Expected list item type $T, got ${item.runtimeType}.',
          expected: T,
          actual: item,
        );
      }
      result.add(item);
    }
    return result;
  }
}
