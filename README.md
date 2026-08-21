# tool_schema_generator

A Dart code generator that automatically produces provider-compatible tool schemas for Large Language Models from annotated Dart functions — with a unified runtime registry for dispatch, validation, and multi-provider encoding.

[![pub package](https://img.shields.io/pub/v/tool_schema_generator.svg)](https://pub.dev/packages/tool_schema_generator) [![coverage](https://img.shields.io/codecov/c/github/joedexdev/tool_schema_generator?label=coverage)](https://codecov.io/gh/joedexdev/tool_schema_generator) [![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## Why

When building LLM agents, every provider (OpenAI, Anthropic, Gemini) expects a different JSON envelope to describe callable tools. Writing and maintaining these maps by hand — across multiple providers — is tedious and error-prone.

`tool_schema_generator` solves this with a simple model:

1. **Annotate** your Dart functions with `@Tool()`.
2. **Generate** — `build_runner` produces a `toolRegistry` with provider-shaped schemas and a validated dispatcher.
3. **Use** — pass `tools.schemas.format(.gemini)` to your LLM and call `tools(name, args)` when it responds.

No hand-written JSON. No duplicated schemas. One source of truth.

---

## Features

- **Zero boilerplate** — names, types, nullability, and doc comments are all inferred from Dart syntax.
- **Multi-provider encoding** — one annotation, four provider shapes: OpenAI, Anthropic, Gemini, and MCP.
- **One encoding verb** — `format(SchemaFormat)` everywhere, reading naturally with Dart's enum dot-shorthand: `tools.schemas.format(.gemini)`.
- **Provider-agnostic strict mode** — opt into closed, fully-required schemas with `@Tool(strict: true)`.
- **Type-safe dispatch** — the generated registry validates every argument and routes calls to the right Dart closure.
- **Raw JSON as a first-class citizen** — hand-written `Map<String, Object?>` schemas can be passed directly to `ToolRegistry`; no wrapper required.
- **Runtime composition** — registries can be extended at runtime with `extend()`, mixing generated and ad-hoc tools.
- **Runtime injection** — hide session parameters (user IDs, locale, etc.) from the LLM schema with `@Inject()`.
- **Full type support** — `String`, `int`, `double`, `bool`, `List<T>`, `Map<String, Object?>`, `enum`s, and custom nested classes.
- **`source_gen` compatible** — plays nicely alongside `json_serializable` and other generators.

---

## Installation

```yaml
dependencies:
  tool_schema_generator: ^1.2.0

dev_dependencies:
  build_runner: ^2.15.0
```

---

## Quick Start

### 1. Annotate your functions

```dart
// lib/tools.dart
import 'package:tool_schema_generator/tool_schema_generator.dart';

part 'tools.g.dart';

/// Sends an email to a specific recipient.
@Tool()
Future<void> sendEmail(
  @Describe('Recipient email address') String to,
  @Describe('Subject line') String subject, {
  @Describe('Body content') required String body,
  bool isHtml = false,
}) async {
  // your implementation
}
```

### 2. Run the generator

```bash
dart run build_runner build
```

### 3. Use the generated `tools` collection

```dart
import 'tools.dart';

// ── Pass schemas to any LLM (Gemini, Claude, OpenAI, MCP) ───────────────────
final response = await gemini.generate(
  prompt: 'Send an email to hello@example.com saying Hi!',
  tools: tools.schemas.format(.gemini),               // Gemini FunctionDeclarations
  // tools: tools.schemas.format(.anthropic),         // Anthropic tool shapes
  // tools: tools.schemas.format(.openAi),            // OpenAI function shapes
  // tools: tools.schemas.format(.mcp),               // Model Context Protocol shapes
);

// ── Dispatch the model's tool call ──────────────────────────────────────────
for (final call in response.toolCalls) {
  final value = await tools(call.name, call.arguments);
  print('Tool returned: $value');
}
```

---

## Core API

### `tools` (or `toolRegistry`)

The generated collection implements `Iterable<JsonObject>` / `Iterable<ToolDefinition>`:

#### Multi-Format Schema Encoding

One canonical batch formatter covers every provider — including MCP:

```dart
tools.schemas.format(.gemini);     // All tools as Gemini FunctionDeclarations
tools.schemas.format(.anthropic);  // All tools for Claude (`input_schema`)
tools.schemas.format(.openAi);     // All tools, OpenAI Draft 2020-12 envelope
tools.schemas.format(.mcp);        // All tools for Model Context Protocol
```

Results are memoized per format; `tools.schemas` is itself cached on the registry.

#### Individual Tool Schema Formatting
Each generated getter (e.g. `tools.sendEmail`) returns a `ToolDefinition` with the same
canonical `format(...)` verb:

```dart
// Format for specific providers
tools.sendEmail.format(.gemini);
tools.sendEmail.format(.anthropic);
tools.sendEmail.format(.mcp);
tools.sendEmail.schema.parameters; // Inner parameters schema only
```

#### Dynamic Filtering & Composition
```dart
// Filter tools dynamically:
final publicGeminiTools = tools
    .where((t) => !t.name.startsWith('admin_'))
    .map((t) => t.format(.gemini))
    .toList();

// Combine registries with operator +
final fullSuite = coreTools + pluginTools;
```

#### Legacy `toolRegistry.encode({String? name, SchemaFormat format})` (deprecated)

The pre-1.2 encoding method still works but is deprecated in favor of the paths above.
Unlike `schemas.format`, it filters by each tool's declared `formats:` list.

| Call | Returns |
|---|---|
| `encode()` | All tools, OpenAI format |
| `encode(format: SchemaFormat.gemini)` | All tools, Gemini format |
| `encode(name: 'search')` | 1-element list, that tool, OpenAI format |
| `encode(name: 'search', format: SchemaFormat.anthropic)` | 1-element list, that tool, Anthropic format |

```dart
// Spread a hand-crafted tool alongside generated ones
final allTools = [
  ...toolRegistry.encode(), // prefer tools.schemas.format(.openAi)
  thinkTool, // a raw JsonObject
];

// Single tool by name
final justSearch = toolRegistry['search']!.format(.openAi);
// or, using the generated constant for that function:
const justSearchSchema = searchToolSchema;
```

### `toolRegistry.encoded` (deprecated)

Convenience getter equivalent to `encode()` — use `tools.schemas.format(.openAi)` instead.

### Named getters

The generated subclass exposes a strongly-typed getter per tool, returning a `ToolDefinition` (which is itself a `Map<String, Object?>`):

```dart
// Equivalent to toolRegistry['sendEmail']!.format(.openAi)
final schema = toolRegistry.sendEmail; // ToolDefinition (OpenAI shape)
```

### `toolRegistry.call(name, args)`

Dispatches a tool call. Validates all arguments, calls the Dart function, and returns the raw result.

```dart
final value = await toolRegistry.call(call.name, call.arguments);
```

Throws typed exceptions on failure (see [Error Handling](#error-handling)).

### `toolRegistry.callOrNull(name, args)`

Like `call`, but returns `null` instead of throwing when the name is not registered. Useful in multi-registry fan-out patterns.

### `toolRegistry.extend(tools)`

Returns a new `ToolRegistry` that merges the current tools with `additionalTools`. On name collision, the later entry wins.

```dart
// Mix generated tools with a raw JSON schema at runtime
final extendedRegistry = toolRegistry.extend([
  {'type': 'function', 'function': {'name': 'thinkTool', 'parameters': {...}}},
]);

// Compose two generated registries
final combined = registryA.extend(registryB);
```

---

## Annotations

### `@Tool()`

Marks a top-level function as an LLM-callable tool.
The annotation is targeted to top-level functions, so invalid placements are
reported by the analyzer and by the generator.

```dart
@Tool(
  name: 'custom_name',          // optional — defaults to Dart function name
  description: 'Override ...',  // optional — defaults to doc comment
  strict: true,                 // optional — defaults to false
  formats: [                    // optional — defaults to all four
    SchemaFormat.openAi,
    SchemaFormat.anthropic,
    SchemaFormat.gemini,
    SchemaFormat.mcp,
  ],
)
```

`strict: true` is additive and opt-in. Existing `@Tool()` declarations keep
their current non-strict behavior.

### `@Describe('...')`

Adds a description to a parameter. Without it, the parameter still appears in the schema but has no `"description"` field.

```dart
@Tool()
void search(
  @Describe('The search query string') String query,
  @Describe('Max number of results, 1–50') int limit,
) {}
```

### `@Inject()`

Hides a named parameter from the schema sent to the LLM. The value is still available to the handler via the `args` map, so you can inject session context at call time.

```dart
@Tool()
Future<void> createTask(
  @Describe('Task title') String title, {
  @Inject() String? userId,    // hidden from schema, merged before dispatch
  @Inject() String locale = 'en',
}) async { ... }

// Dispatch — merge runtime context before calling
await toolRegistry.call(call.name, {
  ...call.arguments,
  'userId': session.userId,
  'locale': request.locale,
});
```

Rules for `@Inject()`:
- Only on **named** parameters.
- Must be **optional** — nullable or have a Dart default value.
- Cannot be `required`.

---

## Strict Mode

Strict mode is useful when you want the model to follow the tool schema as
closely as the provider allows. Enable it per tool:

```dart
@Tool(strict: true)
Future<void> createTask({
  required String title,
  String? notes,
}) async {}
```

For strict tools, the generated parameter schema is transformed before it is
emitted:

- Every visible parameter is listed in `required`, including nullable and
  defaulted parameters.
- Nullable schemas use JSON Schema union types such as
  `{"type": ["string", "null"]}` instead of `"nullable": true`.
- Every object schema, including nested custom classes, gets
  `"additionalProperties": false`.
- OpenAI and Anthropic envelopes include `"strict": true`.
- Gemini receives the same strict-shaped parameter schema, without an extra
  provider-specific strict flag.

Strict mode intentionally rejects Dart types that cannot be represented as a
closed JSON Schema during generation. This includes `dynamic`, `void`,
free-form `Map<...>` parameters, raw lists without item types, recursive object
graphs, and nested fields with those shapes. Use concrete typed classes when a
tool needs strict behavior.

---

## Multi-Provider Encoding

### Provider schema shapes

`SchemaFormat` controls which envelope is emitted:

| `SchemaFormat` | Envelope shape |
|---|---|
| `openAi` | `{"type": "function", "function": {"name": ..., "description": ..., "parameters": ...}}` |
| `anthropic` | `{"name": ..., "description": ..., "input_schema": ...}` |
| `gemini` | `{"name": ..., "description": ..., "parameters": ...}` |
| `mcp` | `{"name": ..., "description": ..., "inputSchema": ...}` |

All four share the same provider-agnostic JSON Schema for the parameters — only the outer envelope changes. Encode any of them with one verb:

```dart
tools.schemas.format(.openAi);     // or .anthropic / .gemini / .mcp
```

> **No implicit default:** `format(...)` always requires an explicit `SchemaFormat` —
> nothing silently assumes OpenAI. The only defaulted member is the deprecated
> `ToolDefinition.encode([format])` shim (defaults to `openAi`).

When `@Tool(strict: true)` is used, OpenAI and Anthropic encodings also include
their strict flag. The canonical parameter schema remains provider-neutral.

### Restricting a tool to specific providers

```dart
// This tool only appears when encoding for Anthropic
@Tool(formats: [SchemaFormat.anthropic])
Future<String> claudeOnlySearch(String query) async => '...';

// toolRegistry.encode(format:) (deprecated) filters by the declared formats list:
toolRegistry.encode(format: SchemaFormat.openAi); // does not include claudeOnlySearch
toolRegistry.encode(format: SchemaFormat.anthropic); // includes it

// schemas.format(...) always formats every registered definition:
tools.schemas.format(.anthropic); // includes claudeOnlySearch
```

---

## Type Support

The generator maps Dart types to JSON Schema types:

| Dart type | JSON Schema |
|---|---|
| `String` | `{"type": "string"}` |
| `int` | `{"type": "integer"}` |
| `double` | `{"type": "number"}` |
| `bool` | `{"type": "boolean"}` |
| `List<T>` | `{"type": "array", "items": <schema for T>}` |
| `Map<String, Object?>` | `{"type": "object"}` |
| `T?` (nullable) | non-strict schemas add `"nullable": true`; strict schemas use JSON Schema unions such as `{"type": ["string", "null"]}` |
| `enum Foo { a, b }` | `{"type": "string", "enum": ["a", "b"]}` |
| Custom class `Foo` | `{"type": "object", "properties": {...}, "required": [...]}` |

### Enums

```dart
enum Priority { low, normal, high }

@Tool()
void setTaskPriority(Priority priority) {}
// → {"type": "string", "enum": ["low", "normal", "high"]}
```

The generated dispatcher also emits a `_parseEnum<T>` helper that validates
the raw string and throws `InvalidToolArgumentException` on unknown values.

### Nested objects

The generator inspects the class's primary constructor to build the nested schema. Required constructor parameters become JSON Schema `required` entries.

```dart
class GeoLocation {
  final double latitude;
  final double longitude;
  GeoLocation({required this.latitude, required this.longitude});
}

@Tool()
void findNearbyPlaces(
  @Describe('The center point') GeoLocation location,
  double radiusKm,
) {}
// → {"type": "object", "properties": {"latitude": ..., "longitude": ...}, "required": ["latitude", "longitude"]}
```

---

## Error Handling

All dispatch errors are subtypes of `ToolCallException`:

| Exception | When |
|---|---|
| `ToolNotFoundException` | No tool registered under that name |
| `MissingToolArgumentException` | A required argument was absent from the args map |
| `InvalidToolArgumentException` | Wrong type, wrong enum value, or list item type mismatch |
| `ToolExecutionException` | The tool function itself threw an unhandled exception |

```dart
try {
  final value = await toolRegistry.call(call.name, call.arguments);
  sendToModel(value.toString());
} on ToolNotFoundException catch (e) {
  print('Unknown tool: ${e.name}. Available: ${e.available}');
} on MissingToolArgumentException catch (e) {
  print('Missing field: ${e.field}');
} on InvalidToolArgumentException catch (e) {
  print('Bad value for ${e.field}: expected ${e.expected}, got ${e.actual}');
} on ToolExecutionException catch (e) {
  print('Tool crashed: ${e.error}');
}
```

---

## Raw JSON as First-Class Input

`ToolRegistry` accepts raw `Map<String, Object?>` schemas directly — no wrapper needed. This is the primary path for integrating with external tool-calling standards (MCP, custom adapters, etc.).

```dart
// Both ToolDefinitions and raw maps are accepted
final registry = ToolRegistry([
  ...toolRegistry,                  // spread from generated registry
  {'type': 'function', 'function': {'name': 'thinkTool', 'parameters': {...}}},
]);

// extend() also accepts raw maps
final extended = toolRegistry.extend([rawToolSchema]);
```

`ToolDefinition.raw()` normalises both envelope shapes:
- `{"type": "function", "function": {...}}` (OpenAI-style) — used as-is.
- `{"name": ..., "parameters": ...}` (flat, Gemini/Anthropic-style) — wrapped automatically.

---

## Architecture & Internals

The generator uses a small compiler-style pipeline:

```
Dart elements
  -> ToolParser
  -> ToolSpec / ParameterSpec / SchemaSpec
  -> optional strict schema transform
  -> ToolSchemaGenerator / ToolDispatchEmitter
```

This keeps Dart analysis, schema transformation, and source rendering separate.
The public runtime API still centers on `ToolRegistry`, `ToolDefinition`, and
the generated `toolRegistry`.

### SchemaSpec intermediate representation

`TypeMapper` maps Dart types into an internal `SchemaSpec` tree instead of
building schema source strings directly. `ToolParser` then wraps those schema
nodes into `ToolSpec` and `ParameterSpec` models. The emitters are the only
layers that turn those specs into generated Dart source.

That split matters because schema changes can now be tested and transformed as
data. Strict mode, for example, recursively walks the `SchemaSpec` tree to close
object schemas and expand `required` lists before code is emitted.

### `ToolDefinition` extends `MapView`

A `ToolDefinition` **is** an OpenAI-compatible `Map<String, Object?>`. It stores one canonical representation internally (the OpenAI `{"type": "function", ...}` envelope) and derives the other provider shapes on demand in `encode(SchemaFormat)`:

```
ToolDefinition
 ├── name, description, parametersSchema  ← single source of truth
 ├── formats                              ← which providers support this tool
 ├── handler                              ← the Dart closure
 └── encode(SchemaFormat) →
      openAi     → Map.unmodifiable(this)          // re-uses the stored map
      anthropic  → {"name", "description", "input_schema": parametersSchema}
      gemini     → {"name", "description", "parameters": parametersSchema}
      mcp        → {"name", "description", "inputSchema": parametersSchema}
```

No pre-baked map per format. Provider shapes are derived lazily at encode time — one switch is the single source of truth for every provider, including MCP.

### `ToolRegistry` extends `IterableBase<JsonObject>`

The registry's backing store is a single `Map<String, ToolDefinition>`. Because `ToolRegistry` extends `IterableBase`, its `iterator` yields `ToolDefinition` values directly — meaning `for (final tool in toolRegistry)` and spreading `[...toolRegistry]` both iterate the OpenAI-shaped maps (since `ToolDefinition extends MapView`).

```
ToolRegistry
 ├── _tools: Map<String, ToolDefinition>
 ├── iterator → _tools.values.iterator  (each value IS a JsonObject)
 ├── encode({name?, format}) → List<JsonObject>   ← unified API
 ├── call(name, args) → Future<Object?>
 ├── extend(tools) → new ToolRegistry
 └── static getRequiredArg / getOptionalArg / ...  ← shared argument helpers
```

### What the generator emits

For each `@Tool`-annotated function, `build_runner` produces three things:

1. **`const <functionName>ParametersSchema`** — a `Map<String, Object?>` of the JSON Schema.
2. **`const <functionName>ToolSchema`** — the full OpenAI envelope wrapping the parameters schema.
3. A `ToolDefinition(...)` entry inside the `toolRegistry` initialiser, including the `formats` list and a typed `handler` closure.

The handler closure uses the static helpers on `ToolRegistry` for validation:

```dart
handler: (JsonObject args) async {
  return getWeather(
    ToolRegistry.getRequiredArg<String>(args, 'city'),
    unit: _parseEnum(
      TemperatureUnit.values,
      ToolRegistry.getOptionalArg<String>(args, 'unit'),
      'unit',
    ) ?? TemperatureUnit.celsius,
  );
},
```

The generated subclass of `ToolRegistry` adds one named getter per tool:

```dart
final class _ToolRegistry extends ToolRegistry {
  _ToolRegistry(super.tools);
  ToolDefinition get getWeather => this['getWeather']!;
  ToolDefinition get sendEmail  => this['sendEmail']!;
}
```

### What this architecture unlocks

The new parser/spec/emitter split is mainly an internal refactor, but it makes
future schema work much safer:

- More focused unit tests against `ToolSpec` and `SchemaSpec`, without fragile
  generated-string assertions.
- Provider-specific schema adapters, if future providers need them, without
  duplicating Dart analysis logic.
- Additional JSON Schema constraints such as string formats, numeric ranges,
  list length limits, and richer object validation.
- Clearer build-time diagnostics for unsupported strict-mode shapes.
- Easier evolution of provider envelopes while keeping one canonical parameter
  schema.

---

## Migrating to 1.2.0

1.2.0 introduces the idiomatic `tools` collection, `SchemaFormat.mcp`, and a single
canonical encoding path: `format(SchemaFormat)` — reading naturally with Dart's enum
dot-shorthand (`format(.gemini)`) on SDK ≥3.10.

### From `toolRegistry` to `tools`
Generated files now emit `final tools = _ToolRegistry([...]);` and keep
`final toolRegistry = tools;` as a backwards-compatible alias.

```dart
// Before (1.1.x)
final response = await llm.generate(tools: toolRegistry.encode());
// After
final response = await llm.generate(tools: tools.schemas.format(.openAi));
```

### Encoding cheat sheet

| Task | 1.2.0 |
|---|---|
| All tools → any provider | `tools.schemas.format(.gemini)` / `.anthropic` / `.openAi` / `.mcp` |
| One tool → any provider | `tools['getWeather']!.format(.gemini)` |
| Parameters schema only | `tools.getWeather.schema.parameters` |
| Runtime name check | `tools.hasTool('getWeather')` |

### Deprecated (removed in 2.0)

| Shipped ≤1.1.0 | Replacement |
|---|---|
| `toolRegistry.encode()` / `.encoded` | `tools.schemas.format(.openAi)` |
| `toolRegistry.encode(format: f)` | `tools.schemas.format(f)` |
| `toolRegistry.encode(name: 'x', ...)` | `tools['x']!.format(...)` |
| `toolRegistry.allSchemas` | `tools.schemas.format(.openAi)` |
| `toolDefinition.encode([f])` | `toolDefinition.format(f)` |

Note: deprecated `registry.encode(format:)` is the only path that filters by each tool's
declared `formats:` list; `schemas.format(...)` formats every registered definition.

### ⚠️ `SchemaFormat.mcp`

Adding an enum constant breaks exhaustive `switch` statements over `SchemaFormat`;
add a `case SchemaFormat.mcp:` (or default) when upgrading. Minimum SDK is now **3.11**.

---

## Contributing

Contributions are welcome — please open a PR with a clear description of the problem and the change.

## License

MIT
