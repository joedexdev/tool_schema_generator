import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/tool_schema_generator.dart';

/// Builder factory for the tool schema generator.
///
/// This is the entry point referenced by `build.yaml`. It creates a
/// [SharedPartBuilder] that uses [ToolSchemaGenerator] to process
/// `@Tool()`-annotated functions and emit `.g.dart` part files.
Builder toolSchemaBuilder(BuilderOptions options) =>
    SharedPartBuilder([ToolSchemaGenerator()], 'tool_schema');
