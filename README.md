# tool_schema_generator

A code generator for Dart that automatically produces JSON Schema (Draft 2020-12) tool definitions for Large Language Models (LLMs) from your annotated Dart functions.

[![pub package](https://img.shields.io/pub/v/tool_schema_generator.svg)](https://pub.dev/packages/tool_schema_generator)

If you are building AI agents with Gemini, OpenAI, Claude, or other LLMs, you often need to provide a JSON schema describing the tools (functions) the model can call. Instead of writing and maintaining massive JSON maps by hand, `tool_schema_generator` lets you write standard Dart functions and automatically generates the precise schemas your LLM needs.

---

## 🌟 Features

- **Zero Boilerplate:** Automatically infers types, names, and nullability directly from Dart syntax.
- **Full Analyzer Support:** Supports `String`, `int`, `double`, `bool`, `List<T>`, `Map<String, dynamic>`, `enum`s, and custom nested classes.
- **Seamless Integration:** Uses the canonical `source_gen` combining builder. It outputs to a standard `.g.dart` file and plays nicely alongside other generators like `json_serializable`.
- **Customizable:** Override tool names and descriptions, or let it automatically extract descriptions from your Dart doc comments.

## 📦 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  tool_schema_generator: ^0.1.0

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
dart run build_runner build -d
```

### 3. Use the generated schema

The generator creates a `tools.g.dart` file containing a `Map<String, dynamic>` constant for each tool, as well as an `allToolSchemas` list containing all tools in the file. 

You can now pass these schemas directly to your LLM framework!

```dart
import 'tools.dart';

void main() {
  final schemas = allToolSchemas;
  
  // schemas looks exactly like this:
  // [
  //   {
  //     "type": "function",
  //     "function": {
  //       "name": "sendEmail",
  //       "description": "Sends an email to a specific user.",
  //       "parameters": {
  //         "type": "object",
  //         "properties": {
  //           "to": {
  //             "type": "string",
  //             "description": "The email address of the recipient"
  //           },
  //           "subject": {
  //             "type": "string",
  //             "description": "The subject line of the email"
  //           },
  //           "body": {
  //             "type": "string",
  //             "description": "The main body content"
  //           },
  //           "isHtml": {
  //             "type": "boolean"
  //           }
  //         },
  //         "required": ["to", "subject", "body"]
  //       }
  //     }
  //   }
  // ]
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

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.
