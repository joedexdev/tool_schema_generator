# Migration Guide

This guide covers upgrading from `0.4.x` to `1.0.0`.

The 1.0 release keeps the package focused on the same workflow:

1. Annotate top-level Dart functions with `@Tool()`.
2. Run `build_runner`.
3. Pass `toolRegistry.encode(...)` to your LLM.
4. Dispatch model tool calls with `toolRegistry.call(...)`.

The breaking changes for `0.4.x` users are naming cleanup, a unified encode
API, regenerated output, and stricter diagnostics for invalid annotation
placement. A short note for projects still carrying pre-`0.4.0` dispatch code
is included near the end.

## Quick Checklist

- Change `SchemaFlavor` to `SchemaFormat`.
- Change `@Tool(flavors: [...])` to `@Tool(formats: [...])`.
- Change `ToolDefinition.flavors` to `ToolDefinition.formats`.
- Replace `toolRegistry.encodeAll(flavor)` with
  `toolRegistry.encode(format: format)`.
- Replace `toolRegistry.encode(name, flavor)` with
  `toolRegistry.encode(name: name, format: format)`.
- Expect every `encode(...)` call to return `List<JsonObject>`.
- Regenerate generated files with
  `dart run build_runner build --delete-conflicting-outputs`.
- Move any invalid `@Tool()` annotations to top-level functions.

## 1. Rename SchemaFlavor To SchemaFormat

`SchemaFlavor` was renamed to `SchemaFormat` because the value controls the
provider envelope format.

Before:

```dart
final schemas = toolRegistry.encodeAll(SchemaFlavor.gemini);
```

After:

```dart
final schemas = toolRegistry.encode(format: SchemaFormat.gemini);
```

## 2. Rename flavors To formats

The annotation and runtime property use the same naming.

Before:

```dart
@Tool(flavors: [SchemaFlavor.openAi, SchemaFlavor.anthropic])
Future<String> search(String query) async => '...';
```

After:

```dart
@Tool(formats: [SchemaFormat.openAi, SchemaFormat.anthropic])
Future<String> search(String query) async => '...';
```

For hand-written tool definitions:

```dart
ToolDefinition(
  name: 'search',
  description: 'Searches content',
  parametersSchema: schema,
  handler: handler,
  formats: [SchemaFormat.openAi],
);
```

## 3. Use The Unified encode API

The old registry encode methods were merged into one named-argument API.

Before:

```dart
final allOpenAi = toolRegistry.encodeAll(SchemaFlavor.openAi);
final allGemini = toolRegistry.encodeAll(SchemaFlavor.gemini);
final oneAnthropic = toolRegistry.encode('search', SchemaFlavor.anthropic);
```

After:

```dart
final allOpenAi = toolRegistry.encode();
final allGemini = toolRegistry.encode(format: SchemaFormat.gemini);
final oneAnthropic = toolRegistry.encode(
  name: 'search',
  format: SchemaFormat.anthropic,
);
```

`encode(...)` always returns `List<JsonObject>`, even when you request one tool.
Use `.first` if your LLM client expects a single schema object.

```dart
final searchSchema = toolRegistry.encode(name: 'search').first;
```

## 4. Regenerate Generated Files

Generated files from `0.4.x` still contain the old names. Regenerate them after
updating source code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated registry now emits `formats:`, `SchemaFormat.*`, strict schema
metadata, and typed dispatcher helpers.

## 5. Check Annotation Placement

`@Tool`, `@Describe`, and `@Inject` now declare analyzer-visible targets.

- `@Tool()` belongs on top-level functions.
- `@Describe(...)` belongs on parameters.
- `@Inject()` belongs on optional named parameters.

Invalid placements now show earlier IDE/analyzer diagnostics, and invalid
`@Tool()` placement fails generation with a clear error.

## 6. Know What Changed For Strict Mode

Strict mode is opt-in:

```dart
@Tool(strict: true)
Future<void> createTask({String? notes}) async {}
```

In strict schemas, nullable Dart types render as JSON Schema union types:

```dart
<String, Object?>{
  'type': <String>['string', 'null'],
}
```

Non-strict schemas keep the older nullable shape:

```dart
<String, Object?>{
  'nullable': true,
  'type': 'string',
}
```

Strict tools also require every visible property and close object schemas with
`additionalProperties: false`. Unsupported shapes such as `dynamic`,
free-form maps, raw lists, and recursive object graphs fail at generation time.

## If You Still Have Pre-0.4 Dispatch Code

The following changes landed in `0.4.0`, so most `0.4.x` users have already
done them. They are included here because old generated/tool-call integration
code is often copied forward between projects.

### Update Dispatch Handling

`toolRegistry.call(...)` returns the raw Dart function value. It no longer
wraps successful calls in `ToolSuccess`, and failures are reported with typed
exceptions.

Before:

```dart
final result = await toolRegistry.call(call.name, call.arguments);

switch (result) {
  case ToolSuccess(:final value):
    sendToModel(value.toString());
  case ToolError(:final code, :final message):
    log('$code: $message');
}
```

After:

```dart
try {
  final value = await toolRegistry.call(call.name, call.arguments);
  sendToModel(value.toString());
} on ToolNotFoundException catch (e) {
  log('Unknown tool: ${e.name}');
} on MissingToolArgumentException catch (e) {
  log('Missing argument: ${e.field}');
} on InvalidToolArgumentException catch (e) {
  log('Invalid argument ${e.field}: ${e.message}');
} on ToolExecutionException catch (e) {
  log('Tool failed: ${e.error}');
}
```

`callOrNull(...)` is still available when you want unknown tool names to return
`null` instead of throwing.

### Use JsonObject For Dispatch Arguments

The registry APIs use `JsonObject`, which is an alias for
`Map<String, Object?>`.

Before:

```dart
Future<void> handle(Map<String, dynamic> args) async {
  await toolRegistry.call('search', args);
}
```

After:

```dart
Future<void> handle(JsonObject args) async {
  await toolRegistry.call('search', args);
}
```

Existing map literals usually keep working, but public APIs should prefer
`JsonObject` / `Map<String, Object?>`.

## Complete Before/After

Before:

```dart
@Tool(flavors: [SchemaFlavor.openAi])
Future<String> search(String query) async => 'result';

final tools = toolRegistry.encodeAll(SchemaFlavor.openAi);
final result = await toolRegistry.call('search', {'query': 'dart'});
```

After:

```dart
@Tool(formats: [SchemaFormat.openAi])
Future<String> search(String query) async => 'result';

final tools = toolRegistry.encode(format: SchemaFormat.openAi);
final value = await toolRegistry.call('search', {'query': 'dart'});
```

Then regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```
