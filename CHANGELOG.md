## 1.0.0

Stable 1.0 release. This keeps the `1.0.0-dev1` architecture and strict-mode
work intact, and adds the final hardening needed for the stable package.

### Added

* **Analyzer-visible annotation targets** for `@Tool`, `@Describe`, and
  `@Inject`, so invalid annotation placement is reported earlier in IDEs.
* **Strict nullable schemas use JSON Schema unions** such as
  `{"type": ["string", "null"]}` instead of generated `"nullable": true`.
  Non-strict nullable output remains backward compatible.

### Fixed

* Generated Dart string literals now safely escape dollar signs, quotes,
  backslashes, newlines, carriage returns, tabs, and control characters.
* Invalid `@Tool()` placement now fails generation with a clear diagnostic
  instead of being skipped.

### Documentation

* Updated installation snippets for `^1.0.0`.
* Documented strict nullable union rendering and annotation placement
  diagnostics.

---

## 1.0.0-dev1

This release implements the next-phase generator architecture and adds
provider-agnostic strict schemas without breaking the existing runtime API.

### Added

* **Provider-agnostic strict mode** via `@Tool(strict: true)`.
  Strict tools generate closed object schemas with
  `additionalProperties: false`, require every visible property, and emit
  provider strict flags for OpenAI and Anthropic.
* **Build-time strict validation** rejects Dart shapes that cannot be safely
  represented as closed schemas, including `dynamic`, `void`, free-form maps,
  raw lists, recursive object graphs, and nested fields with those shapes.

### Internal

* The generator now uses a compiler-style intermediate representation:
  `ToolParser` extracts `ToolSpec` and `ParameterSpec` models, while
  `TypeMapper` produces a structured `SchemaSpec` tree instead of raw schema
  source strings.
* Schema transformations, including strict mode, now operate on `SchemaSpec`
  data before the final Dart source emitter runs.

### Documentation

* Documented strict mode, strict validation, the parser/spec/emitter pipeline,
  and the future schema improvements unlocked by the new architecture.

### Architecture Notes

This release keeps the public runtime API backward compatible while making the
generator easier to evolve. The new parser/spec/emitter split unlocks safer
future work such as richer JSON Schema constraints, clearer strict-mode
diagnostics, provider-specific envelope evolution, and more focused tests that
do not depend on generated-string matching.

---

## 1.0.0-dev0

This release is a **pre-release milestone** that consolidates and formalises
the package's public API ahead of a stable 1.0 launch. The surface area is now
considered complete and frozen for the 1.x series; only additive changes and
bug fixes are expected before 1.0.0.

### Breaking

* **`SchemaFlavor` renamed to `SchemaFormat`** — the old name implied informal
  variation; the new name accurately describes what changes (the JSON envelope
  format emitted for each provider).
* **`@Tool(flavors: [...])` renamed to `@Tool(formats: [...])`** — matches the
  `SchemaFormat` rename above.
* **`ToolDefinition.flavors` renamed to `ToolDefinition.formats`** — same
  alignment.
* **`ToolRegistry.encodeAll(SchemaFlavor)` removed** — replaced by the unified
  `encode({String? name, SchemaFormat format})` method (see below).
* **`ToolRegistry.encode(String name, [SchemaFlavor])` removed** — merged into
  the same unified `encode` method.

### Added

* **Unified `ToolRegistry.encode({String? name, SchemaFormat format})`** —
  single method that covers all encoding use cases. Always returns
  `List<JsonObject>` for a consistent return type regardless of call site.
  Named parameters make intent explicit at the call site:
  - `encode()` → all tools, OpenAI format
  - `encode(format: SchemaFormat.gemini)` → all tools, Gemini format
  - `encode(name: 'search')` → 1-element list, OpenAI format
  - `encode(name: 'search', format: SchemaFormat.anthropic)` → 1-element list, Anthropic format
* **`ToolRegistry.encoded` getter** — convenience alias for `encode()`,
  returning all tools in OpenAI format. Retained for ergonomic one-liner use.

### Internal

* `ToolDefinition.encode([SchemaFormat])` (lowercase `format` parameter)
  remains the per-definition internal encoding method, used by the registry's
  `encode` implementation. It derives the provider envelope lazily at call time
  from the single stored canonical representation — no pre-baked maps per
  format.
* The code generator now emits `formats:` and `SchemaFormat.*` in the
  generated `tools.g.dart` files. Existing generated files must be regenerated
  with `dart run build_runner build --delete-conflicting-outputs`.

---

## 0.4.0

### Breaking

* Replaced `ToolResult`, `ToolSuccess`, and `ToolError` dispatch results with raw `ToolRegistry.call` return values and typed exceptions.
* Replaced `Map<String, dynamic>` dispatch arguments with `JsonObject` (`Map<String, Object?>`) in the public registry API and generated handlers.

### Added

* Added `SchemaFlavor` and `@Tool(flavors: [...])` for OpenAI, Anthropic, and Gemini provider-shaped schema generation.
* Added `encodeAll(SchemaFlavor flavor)` and flavor-aware `encode(name, flavor)` registry APIs.
* Added centralized argument validation helpers and strict enum validation.
* Added generator validation for duplicate tool names.

### Fixed

* Deduplicated repeated `@Tool(flavors: [...])` entries.
* Generated enum parsing support for enum fields inside nested class parameters.

## 0.3.0

### Added

* Added `@Inject()` for named tool parameters that should be hidden from the generated LLM schema.
* Injected parameters are still read from the `args` map passed to `toolRegistry.call`, so application code can merge runtime values before dispatch.
* Added generator validation for injected parameters:
  * `@Inject()` can only be used on named parameters.
  * Injected parameters cannot be `required`.
  * Injected parameters must be nullable or have a Dart default value.

### Fixed

* Fixed generated argument parsing for parameters with Dart defaults so omitted values safely fall back to the default before casting errors occur.

### Documentation

* Documented runtime injection usage and the merged-arguments invocation pattern.

## 0.2.1

* **Documentation:** Updated README with detailed usage guide for tool dispatching, error handling, and registry life-cycle.

## 0.2.0

### New: Tool Dispatcher & Subclass Schema Getters

This release adds a complete dispatcher layer so you can invoke tools by name with the raw argument maps your LLM returns — with no boilerplate.

* **Named Schema Getters:** The code generator now emits a private subclass of `ToolRegistry` that provides strongly-typed getters for each tool schema. You can now use `toolRegistry.myToolName` instead of manually importing the `<myToolName>ToolSchema` constant.
* Added `schemaFor(String name)` and `allSchemas` to `ToolRegistry`. You can now pass `toolRegistry.allSchemas` directly to your LLM framework.


#### New public API

**`ToolRegistry`**
- `Future<ToolResult> call(String name, Map<String, dynamic> args)` — dispatch a tool call
- `Future<ToolResult>? callOrNull(String name, Map<String, dynamic> args)` — returns `null` for unknown tools instead of throwing
- `bool contains(String name)` — check if a tool is registered
- `Iterable<String> get toolNames` — enumerate registered tools

**`ToolResult`** (sealed class)
- `ToolSuccess(dynamic value)` — tool ran successfully
- `ToolError({String code, String message, String? field, dynamic expected, dynamic actual})` — structured, machine-readable failure

**Error codes emitted by `ToolError`:**
| Code | Trigger |
|---|---|
| `UNKNOWN_TOOL` | No tool with that name is registered (throws `UnknownToolException`) |
| `INVALID_ARGUMENT` | LLM sent a wrong type for a parameter |
| `MISSING_ARGUMENT` | A required parameter was absent |
| `INTERNAL_ERROR` | Unexpected exception inside the tool function |

**`ToolArgumentException`** — thrown internally by generated parsers; caught at registry boundary.

**`UnknownToolException`** — thrown by `ToolRegistry.call()` when the name is not registered. Includes `available` list.

#### Generator changes

The generator now emits, alongside each schema constant, a `final toolRegistry = ToolRegistry({...})` containing a handler closure per tool. Handlers:
- Cast every parameter safely with `as Type` (or `(num).toDouble()` for `double`)
- Respect nullable/optional params with `?? defaultValue` fallbacks
- Generate `_parseEnum<T>` helpers for enum-typed params (deduplicated)
- Generate `_parse<ClassName>` helpers for custom class params (user-defined only)
- Wrap all invocations in `Future.sync(...)` for uniform `Future<dynamic>` return type

#### Usage

```dart
final result = await toolRegistry.call(toolCall.name, toolCall.arguments);
switch (result) {
  case ToolSuccess(:final value): submitToModel(value.toString());
  case ToolError(:final code, :final message): print('$code: $message');
}
```

---

## 0.1.0

* **Initial Release:** First version of `tool_schema_generator`.
* Introduced `@Tool()` and `@Describe()` annotations for Dart functions.
* Full integration with `build_runner` and `source_gen:combining_builder` (works seamlessly alongside `json_serializable`).
* Support for primitive types, enums, nullables, lists, maps, and nested classes.
* Generates JSON Schema Draft 2020-12 compatible maps.
