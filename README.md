# tool_schema_generator

A code generator for Dart that automatically produces provider-compatible tool schemas for Large Language Models (LLMs) from your annotated Dart functions.

[![pub package](https://img.shields.io/pub/v/tool_schema_generator.svg)](https://pub.dev/packages/tool_schema_generator)

If you are building AI agents with Gemini, OpenAI, Claude, or other LLMs, you often need to provide a schema describing the tools (functions) the model can call. Instead of writing and maintaining provider-specific JSON maps by hand, `tool_schema_generator` lets you write standard Dart functions and automatically generates the precise schemas your LLM needs.

---

## 🌟 Features

- **Zero Boilerplate:** Automatically infers types, names, and nullability directly from Dart syntax.
- **Full Analyzer Support:** Supports `String`, `int`, `double`, `bool`, `List<T>`, `Map<String, Object?>`, `enum`s, and custom nested classes.
- **Provider-Shaped Schemas:** Generates OpenAI, Anthropic, and Gemini tool schema shapes from the same Dart functions.
- **Seamless Integration:** Uses the canonical `source_gen` combining builder. It outputs to a standard `.g.dart` file and plays nicely alongside other generators like `json_serializable`.
- **Customizable:** Override tool names and descriptions, or let it automatically extract descriptions from your Dart doc comments.
- **Runtime Injection:** Hide app-controlled parameters from the LLM schema with `@Inject()` while still passing them during dispatch.

## 📦 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  tool_schema_generator: ^0.4.0

dev_dependencies:
  build_runner: ^2.4.0
```

## 🚀 Quick Start

### 1. Annotate your functions

Create a `.dart` file and use the `@Tool()` annotation on your top-level functions. You can use the `@Describe()` annotation to add rich descriptions to individual parameters.

```dart
// lib/tools.dart
import 'package:tool_schema_generator/tool_schema_generator.dart';

// IMPORTANT: Declare the part file
part 'tools.g.dart';

/// Sends an email to a specific user.
@Tool()
void sendEmail(
  @Describe('The email address of the recipient') String to,
  @Describe('The subject line of the email') String subject, {
  @Describe('The main body content') required String body,
  bool isHtml = false,
}) {
  // Your logic here
}
```

### 2. Run the generator

Run the build runner command in your terminal:

```bash
dart run build_runner build
```

### 3. Use the generated schemas and dispatcher

The generator creates a `tools.g.dart` file containing a `toolRegistry` instance. This registry contains all your schemas and automatically routes LLM tool calls back to your Dart functions safely.

You can pass provider-shaped schemas directly to your LLM framework using `toolRegistry.schemasFor(...)`, or select individual OpenAI-compatible schemas via strongly-typed getters like `toolRegistry.sendEmail`.

- `toolRegistry.schemasFor(SchemaFlavor.openAi)` gives you OpenAI function tool schemas.
- `toolRegistry.schemasFor(SchemaFlavor.anthropic)` gives you Anthropic tool schemas using `input_schema`.
- `toolRegistry.schemasFor(SchemaFlavor.gemini)` gives you Gemini function declarations.
- `toolRegistry.allSchemas` remains an OpenAI-compatible alias.
- `toolRegistry.sendEmail` gives you a single OpenAI-compatible `JsonObject` just for that tool.

Then dispatch when the LLM replies:

```dart
final value = await toolRegistry.call(
  toolCall.name,
  toolCall.arguments
);
```

The registry takes the raw string name and raw `JsonObject` (`Map<String, Object?>`) arguments from the LLM, finds the right Dart closure, validates all arguments, calls your function, and awaits the raw result.

Argument and execution failures are surfaced as typed exceptions:

- `ToolNotFoundException`
- `MissingToolArgumentException`
- `InvalidToolArgumentException`
- `ToolExecutionException`

This gives you a completely type-safe, boilerplate-free bridge between Dart code and LLM agent loops.

```dart
import 'tools.dart';

void main() async {
  // 1. Pass the schemas to your LLM
  final response = await llm.generate(
    prompt: "Send an email to hello@example.com saying Hi!",
    tools: toolRegistry.schemasFor(SchemaFlavor.openAi),
  );

  // 2. When the LLM decides to call a tool, dispatch it.
  for (final toolCall in response.toolCalls) {
    try {
      final value = await toolRegistry.call(
        toolCall.name,
        toolCall.arguments,
      );
      print("Tool returned: $value");
    } on ToolCallException catch (error) {
      print("Tool failed: ${error.message}");
    }
  }
}
```

## 🧠 Advanced Usage

### Enums

Enums are automatically converted to JSON Schema string enums:

```dart
enum Priority { low, normal, high }

@Tool()
void setTaskPriority(Priority priority) {}
// Generates: {"type": "string", "enum": ["low", "normal", "high"]}
```

### Nested Objects

Custom classes are introspected. The generator looks at the class's constructor parameters to build a nested JSON Schema object:

```dart
class Location {
  final double lat;
  final double lng;
  Location({required this.lat, required this.lng});
}

@Tool()
void updateLocation(Location location) {}
// Generates nested object with properties `lat` and `lng` (both required).
```

### Overriding Names and Descriptions

If you don't want to use the Dart function name or doc comment, you can override them directly in the annotation:

```dart
@Tool(
  name: 'custom_search_tool',
  description: 'A highly specific search tool description.'
)
void search(String query) {}
```

### Provider Flavors

By default, every tool is generated for OpenAI, Anthropic, and Gemini. You can limit a tool to specific provider shapes:

```dart
@Tool(flavors: [SchemaFlavor.anthropic])
Future<String> searchClaudeOnly(String query) async => '...';
```

The generated registry groups schemas by flavor:

```dart
final anthropicTools = toolRegistry.schemasFor(SchemaFlavor.anthropic);
final openAiSendEmail = toolRegistry.sendEmail;
```

### Injected Runtime Parameters

Use `@Inject()` for app-controlled named parameters that should not appear in
the schema sent to the LLM. Injected parameters are still read from the same
arguments map passed to `toolRegistry.call`, so you can merge values like user
IDs, tenant IDs, or request locale at invocation time.

Injected parameters must be optional: nullable, have a Dart default value, or
both.

```dart
@Tool()
Future<void> createTask(
  @Describe('Task title') String title, {
  @Inject() String? userId,
  @Inject() String locale = 'en',
}) async {
  // userId and locale are available here, but only title is in the schema.
}

final value = await toolRegistry.call(toolCall.name, {
  ...toolCall.arguments,
  'userId': currentUser.id,
  'locale': request.locale,
});
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.
