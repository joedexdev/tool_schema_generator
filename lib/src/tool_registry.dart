import 'dart:collection';
import 'annotations.dart';
import 'tool_definition.dart';
import 'tool_exceptions.dart';

/// A JSON object passed to or produced by tool schema APIs.
typedef JsonObject = Map<String, Object?>;

/// A JSON array passed to or produced by tool schema APIs.
typedef JsonArray = List<Object?>;

/// The signature of every generated tool handler.
///
/// Each handler receives the raw arguments map from the LLM and returns a
/// [Future] that resolves to the tool function's return value.
typedef ToolHandler = Future<Object?> Function(JsonObject args);

/// A registry that maps tool names to their [ToolDefinition]s, providing
/// a unified dispatch + discovery layer between the LLM and your Dart code.
///
/// The generated subclass (from `tool_schema_generator`) extends this class
/// and adds a strongly-typed getter per tool:
///
/// ```dart
/// // Generated in tools.g.dart — do not write this manually
/// final toolRegistry = _ToolRegistry([ toolDefinitions ]);
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
class ToolRegistry extends IterableBase<JsonObject> {
  final Map<String, ToolDefinition> _tools;

  /// Creates a registry.
  ///
  /// [tools] is the list of initial tool definitions or raw JSON schema [Map]s.
  ToolRegistry([Iterable<Object?> tools = const []])
    : _tools = _parseTools(tools);

  static Map<String, ToolDefinition> _parseTools(
    Iterable<Object?> tools,
  ) => Map.fromEntries(
    tools.where((t) => t is ToolDefinition || t is Map<String, Object?>).map((
      t,
    ) {
      if (t is ToolDefinition) return MapEntry(t.name, t);
      final schema = t as Map<String, Object?>;
      final def = ToolDefinition.raw(
        schema: schema,
        handler: (args) async => throw StateError(
          'No execution handler registered for tool "${ToolDefinition.extractName(schema)}".',
        ),
      );
      return MapEntry(def.name, def);
    }),
  );

  @override
  Iterator<JsonObject> get iterator => _tools.values.iterator;

  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Whether a tool with the given [element] is registered.
  @override
  bool contains(Object? element) {
    if (element is String) return _tools.containsKey(element);
    if (element is ToolDefinition) return _tools.containsKey(element.name);
    if (element is Map && element.containsKey('name'))
      return _tools.containsKey(element['name']);
    return _tools.values.contains(element);
  }

  /// All registered tool names.
  Iterable<String> get toolNames => _tools.keys;

  /// Returns the [ToolDefinition] registered under [name], or `null` if not found.
  ToolDefinition? operator [](String name) => _tools[name];

  /// Encodes registered tool schemas into provider-specific JSON.
  ///
  /// - `encode()` — all tools, OpenAI format (default).
  /// - `encode(format: SchemaFormat.gemini)` — all tools, Gemini format.
  /// - `encode(name: 'search')` — that tool only, OpenAI format (1-element list).
  /// - `encode(name: 'search', format: SchemaFormat.anthropic)` — that tool, Anthropic.
  ///
  /// The return type is always `List<JsonObject>`, making spreads and direct
  /// assignment to LLM APIs consistent regardless of scope.
  ///
  /// ```dart
  /// // All tools to OpenAI
  /// llm.generate(tools: toolRegistry.encode());
  ///
  /// // All tools to Gemini
  /// llm.generate(tools: toolRegistry.encode(format: SchemaFormat.gemini));
  ///
  /// // Spread with extra tools
  /// final tools = [...toolRegistry.encode(), thinkTool];
  ///
  /// // Single tool by name
  /// toolRegistry.encode(name: 'search');
  /// ```
  List<JsonObject> encode({
    String? name,
    SchemaFormat format = SchemaFormat.openAi,
  }) {
    if (name != null) {
      final tool = _tools[name];
      if (tool == null) {
        throw StateError(
          'No ${format.name} schema registered for tool "$name". '
          'Available: [${_tools.keys.join(', ')}]',
        );
      }
      return List.unmodifiable([tool.encode(format)]);
    }
    return List.unmodifiable(
      _tools.values
          .where((t) => t.formats.contains(format))
          .map((t) => t.encode(format)),
    );
  }

  /// Convenience getter — all tools encoded in OpenAI format.
  ///
  /// Equivalent to `encode()`.
  List<JsonObject> get encoded => encode();

  // ── Dispatch ──────────────────────────────────────────────────────────────


  /// Invokes the tool registered under [name] with the provided [args] and
  /// returns the raw Dart function value.
  ///
  /// Throws [ToolNotFoundException], [MissingToolArgumentException],
  /// [InvalidToolArgumentException], or [ToolExecutionException].
  Future<Object?> call(String name, JsonObject args) async {
    final tool = _tools[name];
    if (tool == null) {
      throw ToolNotFoundException(name, _tools.keys.toList());
    }

    try {
      return await Future.sync(() => tool.handler(args));
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
    if (!_tools.containsKey(name)) return null;
    return call(name, args);
  }

  // ── Composition ───────────────────────────────────────────────────────────

  /// Returns a new registry with [additionalTools] merged in.
  /// [additionalTools] can contain a mix of [ToolDefinition]s and raw JSON [Map]s.
  /// On name collision, the later definition wins.
  ToolRegistry extend(Iterable<Object?> additionalTools) =>
      ToolRegistry([...this, ...additionalTools]);

  // ── Static Helpers (unchanged — used by all generated code) ────────────────

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
