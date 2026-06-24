# Next-Phase Architecture Report & Refactor Proposal

## Overview

The `tool_schema_generator` package has successfully decoupled provider-specific schema shaping. Rather than generating multiple distinct schema representations at compile time, the generator emits a single, neutral JSON schema map. At runtime, [ToolDefinition](file:///home/joedev/developments/productions/tool_schema_generator/lib/src/tool_definition.dart) dynamically maps this representation to provider-specific envelopes (OpenAI, Anthropic, Gemini) using pattern matching inside its `encode()` method.

This runtime translation has major benefits:
- **Zero Schema Duplication**: Keeps the generated code size extremely small.
- **Dynamic Extensibility**: Allows users to inspect and extend schemas at runtime.
- **Performance**: High performance through static const parameters mapping and lazy runtime encoding.

Because of this runtime-driven encoding, the original phase proposal to build provider-specific encoders inside the generator is **obsolete**. However, clean decoupling of **Dart AST Parsing** from **Dart Code Generation** is still highly valuable.

---

## Architectural Refinements

The next evolution of `tool_schema_generator` should focus on separating analysis and translation from code rendering. Currently, [ToolSchemaGenerator](file:///home/joedev/developments/productions/tool_schema_generator/lib/src/tool_schema_generator.dart) traverses elements twice and directly produces string representations of schemas via [TypeMapper](file:///home/joedev/developments/productions/tool_schema_generator/lib/src/type_mapper.dart).

We propose replacing raw string-based schema generation with a structured **Schema AST (Abstract Syntax Tree)** and introducing clear **specs** to act as a compiler-style Intermediate Representation (IR).

```mermaid
graph TD
    Element[Dart AST Element] -->|Parser / TypeMapper| Specs[Intermediate Specs: ToolSpec & SchemaSpec]
    Specs -->|Strict Transform| SpecsStrict[Transformed Specs if Strict]
    SpecsStrict -->|Code Emitter| GeneratedCode[Generated Dart Source Code]
```

### 1. Spec Models (IR)
Introduce compiler-neutral data structures representing the extracted metadata:
- **`ToolSpec`**: Represents the parsed definition of one tool.
  - `String name`
  - `String description`
  - `List<SchemaFormat> formats`
  - `List<ParameterSpec> parameters`
- **`ParameterSpec`**: Represents an exposed tool parameter.
  - `String name`
  - `bool isRequired`
  - `bool isNamed`
  - `bool isInjected`
  - `String? defaultValueCode`
  - `SchemaSpec schema`
- **`SchemaSpec`**: An AST representation of the parameter type schema instead of serialized Dart code strings.
  - Subclasses: `StringSchemaSpec`, `IntegerSchemaSpec`, `NumberSchemaSpec`, `BooleanSchemaSpec`, `ArraySchemaSpec`, `ObjectSchemaSpec`, `EnumSchemaSpec`.
  - Each `SchemaSpec` knows how to render itself to Dart code (e.g., via a `.toDartSource()` method).

### 2. Benefits of the Spec AST Model
- **Classic Compiler Architecture**: Decouples Dart AST parsing from schema rendering, bringing maintainability and extensibility to the generation process.
- **Single-Pass Parsing**: Eliminates double-parsing of library elements, improving performance.
- **Improved Testability**: Allows writing unit tests directly against the parser output (`ToolSpec`) and `SchemaSpec` transformations without doing fragile string matching on generated code.
- **Programmatic Transformations (Strict Mode)**: Crucial for advanced provider-agnostic schema options like Strict Mode.

---

## Key Feature: Provider-Agnostic Strict Mode

The industry is moving toward strict schema adherence. With the **Schema AST Model**, transforming standard schemas into strict representations becomes trivial.

*   **OpenAI (Structured Outputs):** Supports a `strict: true` mode guaranteeing the model's output perfectly matches the schema. This requires:
    1. Setting `"additionalProperties": false` on all object schemas.
    2. Requiring every defined property (including optional/nullable). Nullable fields must be typed properly (e.g., `["type", "null"]`).
*   **Anthropic:** Introduced **Strict Tool Use** via `strict: true` using grammar-constrained sampling. They highly recommend setting `"additionalProperties": false` to prevent hallucinated parameters.
*   **Gemini:** Enforces strict adherence natively (especially in `VALIDATED` or `ANY` function calling modes). A rigidly defined schema from our AST (with explicit required properties and nullability) inherently improves Gemini's reliability.

Implementing these transformations with the current string-based generator is complex and fragile. The AST model solves this elegantly.

### Example Transformation with `SchemaSpec`
If strict mode is enabled, we can run a recursive transformer over the `SchemaSpec`:
```dart
SchemaSpec transformToStrict(SchemaSpec spec) {
  if (spec is ObjectSchemaSpec) {
    return ObjectSchemaSpec(
      properties: spec.properties.map((k, v) => MapEntry(k, transformToStrict(v))),
      required: spec.properties.keys.toList(), // All properties must be in required
      additionalProperties: false, // Disallow additional properties
      isNullable: spec.isNullable,
    );
  }
  if (spec is ArraySchemaSpec) {
    return ArraySchemaSpec(
      items: transformToStrict(spec.items),
      isNullable: spec.isNullable,
    );
  }
  return spec;
}
```

---

## Implementation Phases

### Phase 1: Implement Schema AST (`SchemaSpec`)
Create the structured hierarchy for schemas.
- Add `SchemaSpec` and its subclasses.
- Update `TypeMapper` to return `SchemaSpec` instead of `String`.
- Write unit tests verifying that `TypeMapper` returns the correct `SchemaSpec` trees.

### Phase 2: Implement Tool Specs
Introduce the `ToolSpec` and `ParameterSpec` models.
- Create an internal parser class (`ToolParser`) that scans the `LibraryReader` and constructs a list of `ToolSpec`s.
- Move validations (duplicate tool names, invalid `@Inject` placements) into this parser.
- Write unit tests validating parsing output directly.

### Phase 3: Migrate Generator to Emitters
Update `ToolSchemaGenerator` to use the parsed `ToolSpec`s.
- Rewrite generator logic to map `ToolSpec`s to Dart source code using the specifications and `SchemaSpec.toDartSource()`.
- Ensure all existing tests in `tool_schema_generator_test.dart` remain green.

### Phase 4: Provider-Agnostic Strict Mode Support
Introduce generic strict mode configuration that benefits all supported providers (OpenAI, Anthropic, Gemini).
- Update `@Tool()` annotation to support a `strict` flag:
  ```dart
  class Tool {
    final bool strict;
    // ...
  }
  ```
- Implement the strict transformer for `SchemaSpec`. Ensure the terminology remains generic and not tied solely to OpenAI.
- Update `ToolDefinition` and the generator to support emitting `strict: true` schemas where supported by the provider adapter.
- **Fallback / Validation Strategy**: Ensure the generator throws a clear, helpful compilation error during the build phase if the user attempts to use `strict: true` on a type that fundamentally cannot be made strict under the JSON Schema spec.
- Add test cases checking that strict schemas have `additionalProperties: false` and all properties marked as `required`.

---

## Acceptance Criteria

- **No Public API Breakage**: The public runtime API for `ToolRegistry`, `ToolDefinition`, and existing annotations must remain backward compatible.
- **Generator Output Equivalence**: For non-strict tools, the emitted generated schemas must match the current schema formats exactly.
- **Complete Test Coverage**: Focused tests must cover the parser outputs, `SchemaSpec` representations, and strict-mode transformations.
- **Dry-run Green**: `dart analyze` and `dart pub publish --dry-run` must pass.
