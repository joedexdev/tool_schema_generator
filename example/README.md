# Example usage of `tool_schema_generator`

This example demonstrates how to use the `tool_schema_generator` package to automatically generate provider-compatible LLM tool schemas for your Dart functions.

The sample covers:

- primitive, enum, list, map, and nested-class parameters
- provider selection with `@Tool(formats: [...])`
- generated `toolRegistry` dispatch handlers
- the generated schema output produced by the new parser/spec/emitter architecture

## Setup

1. Add `tool_schema_generator` to your `dependencies`.
2. Add `build_runner` to your `dev_dependencies`.

```yaml
dependencies:
  tool_schema_generator: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.0
```

## Running the generator

After adding your `@Tool()` annotations, run the build runner to generate the `.g.dart` file:

```bash
dart run build_runner build
```

Check out `lib/tools.dart` in this example to see how the annotations are used.
The checked-in `lib/tools.g.dart` file shows the generated registry and schema
maps.

To try strict schemas, add `strict: true` to one of the `@Tool()` annotations:

```dart
@Tool(strict: true)
void findNearbyPlaces(GeoLocation location) {}
```

Strict tools close object schemas with `additionalProperties: false`, require
all visible properties, render nullable fields as JSON Schema type unions, and
emit strict provider flags where supported.
