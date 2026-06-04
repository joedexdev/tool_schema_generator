/// Annotations for automatic LLM tool schema generation.
///
/// Use `@Tool()` to mark top-level functions and `@Describe()` to
/// annotate individual parameters with descriptions.
///
/// Add `tool_schema_generator` as a dependency and `build_runner` as a
/// dev dependency, then run `dart run build_runner build` to generate the schemas.
library tool_schema_generator;

export 'src/annotations.dart';
export 'src/tool_exceptions.dart';
export 'src/tool_registry.dart';
