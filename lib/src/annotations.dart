import 'package:meta/meta_meta.dart';

/// Provider schema formats that can be generated for a tool.
enum SchemaFormat {
  /// OpenAI function tool shape.
  openAi,

  /// Anthropic tool shape.
  anthropic,

  /// Gemini function declaration shape.
  gemini,
}

/// Marks a top-level function as an LLM-callable tool.
///
/// The generator will produce provider-shaped tool schemas for the selected
/// [formats].
///
/// By default, the function's Dart name is used as the tool name and its
/// doc comment is used as the description. Both can be overridden via
/// the annotation parameters.
///
/// Example:
/// ```dart
/// /// Gets the current weather for a given city.
/// @Tool()
/// String getWeather(
///   @Describe('The city name') String city, {
///   @Describe('Temperature unit') String unit = 'celsius',
/// }) {
///   // ...
/// }
/// ```
@Target({TargetKind.function})
class Tool {
  /// Optional override for the tool name.
  ///
  /// When `null`, the generator uses the annotated function's Dart name.
  final String? name;

  /// Optional override for the tool description.
  ///
  /// When `null`, the generator uses the function's doc comment
  /// (with `///` prefixes stripped).
  final String? description;

  /// Provider schema formats generated for this tool.
  ///
  /// By default, the generator emits all supported provider shapes.
  final List<SchemaFormat> formats;

  /// Whether this tool should emit a strict parameter schema.
  ///
  /// Strict tools require every visible property and close object schemas with
  /// `additionalProperties: false`.
  final bool strict;

  /// Creates a [Tool] annotation.
  const Tool({
    this.name,
    this.description,
    this.formats = const [
      SchemaFormat.openAi,
      SchemaFormat.anthropic,
      SchemaFormat.gemini,
    ],
    this.strict = false,
  });
}

/// Annotates a function parameter with a human-readable description
/// that will appear in the generated JSON Schema.
///
/// This is optional — parameters without `@Describe` will still appear
/// in the schema, but without a `"description"` field.
///
/// Example:
/// ```dart
/// @Tool()
/// void search(
///   @Describe('The search query string') String query,
///   @Describe('Maximum number of results to return') int limit,
/// ) {}
/// ```
@Target({TargetKind.parameter})
class Describe {
  /// The human-readable description for this parameter.
  final String description;

  /// Creates a [Describe] annotation.
  const Describe(this.description);
}

/// Marks a named tool parameter as runtime-injected.
///
/// Injected parameters are not included in the generated JSON Schema sent to
/// the LLM. They are still read from the `args` map passed to
/// `toolRegistry.call`, so application code can merge request/session values
/// into the tool call arguments before dispatch.
///
/// Injected parameters must be named and optional: either nullable or have a
/// Dart default value.
///
/// Example:
/// ```dart
/// @Tool()
/// void createTask(
///   String title, {
///   @Inject() String? userId,
///   @Inject() String locale = 'en',
/// }) {}
/// ```
@Target({TargetKind.parameter})
class Inject {
  /// Creates an [Inject] annotation.
  const Inject();
}
