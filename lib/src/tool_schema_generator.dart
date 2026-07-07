import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'dart_source.dart';
import 'tool_dispatch_emitter.dart';
import 'tool_parser.dart';
import 'tool_spec.dart';
import 'type_mapper.dart';

/// Scans top-level functions annotated with `@Tool()` and emits provider-shaped
/// LLM tool schemas plus a generated dispatch registry.
class ToolSchemaGenerator extends Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final typeMapper = TypeMapper();
    final tools = ToolParser(typeMapper: typeMapper).parse(library);
    if (tools.isEmpty) return '';

    final output = StringBuffer();

    for (final tool in tools) {
      output
        ..writeln(_generateSchemasForTool(tool))
        ..writeln();
    }

    output.writeln(
      _generateDispatcher(tools, ToolDispatchEmitter(library: library.element)),
    );
    return output.toString();
  }

  String _generateDispatcher(
    List<ToolSpec> tools,
    ToolDispatchEmitter dispatchEmitter,
  ) {
    final buffer = StringBuffer();

    buffer.writeln(
      '/// Generated registry - provides named schema getters and tool dispatch.',
    );
    buffer.writeln('final class _ToolRegistry extends ToolRegistry {');
    buffer.writeln('  _ToolRegistry(super.tools);');
    buffer.writeln();

    for (final tool in tools) {
      final dartName = tool.element.name;
      buffer.writeln("  /// Tool definition for [$dartName].");
      buffer.writeln(
        '  ToolDefinition get $dartName => this[${dartStringLiteral(tool.name)}]!;',
      );
    }

    buffer.writeln('}');
    buffer.writeln();

    final toolsBuffer = StringBuffer();
    for (final tool in tools) {
      final paramVarName = '${tool.element.name}ParametersSchema';
      final formatsListLiteral =
          'const [${tool.formats.map((f) => 'SchemaFormat.${f.name}').join(', ')}]';

      toolsBuffer.writeln('  ToolDefinition(');
      toolsBuffer.writeln('    name: ${dartStringLiteral(tool.name)},');
      toolsBuffer.writeln(
        '    description: ${dartStringLiteral(tool.description)},',
      );
      toolsBuffer.writeln('    parametersSchema: $paramVarName,');
      toolsBuffer.writeln('    formats: $formatsListLiteral,');
      if (tool.strict) {
        toolsBuffer.writeln('    strict: true,');
      }
      toolsBuffer.writeln('    handler: (JsonObject args) async {');

      final positionalArgs = <String>[];
      final namedArgs = <String>[];
      for (final param in tool.parameters) {
        final expr = dispatchEmitter.argumentExpression(param);
        if (param.isNamed) {
          namedArgs.add('${param.name}: $expr');
        } else {
          positionalArgs.add(expr);
        }
      }
      final allArgs = [...positionalArgs, ...namedArgs].join(', ');
      toolsBuffer.writeln('      return ${tool.element.name}($allArgs);');
      toolsBuffer.writeln('    },');
      toolsBuffer.writeln('  ),');
    }

    buffer.writeln('/// The generated tool registry for this file.');
    buffer.writeln(
      '/// Use [toolRegistry.encode] to get provider-formatted schemas,',
    );
    buffer.writeln('/// and [toolRegistry.call] to dispatch model tool calls.');
    buffer.writeln('final toolRegistry = _ToolRegistry([');
    buffer.write(toolsBuffer.toString());
    buffer.writeln(']);');
    buffer.writeln();

    for (final src in dispatchEmitter.helperSources) {
      buffer.writeln(src);
    }

    return buffer.toString();
  }

  String _generateSchemasForTool(ToolSpec tool) {
    final buffer = StringBuffer();
    final paramVarName = '${tool.element.name}ParametersSchema';
    buffer.writeln(
      'const $paramVarName = ${tool.parametersSchema.toDartSource(useNullUnion: tool.strict)};',
    );
    buffer.writeln();

    final toolVarName = '${tool.element.name}ToolSchema';
    buffer.writeln('const $toolVarName = <String, Object?>{');
    buffer.writeln("  'type': 'function',");
    buffer.writeln("  'function': <String, Object?>{");
    buffer.writeln("    'name': ${dartStringLiteral(tool.name)},");
    buffer.writeln(
      "    'description': ${dartStringLiteral(tool.description)},",
    );
    buffer.writeln("    'parameters': $paramVarName,");
    if (tool.strict) {
      buffer.writeln("    'strict': true,");
    }
    buffer.writeln('  },');
    buffer.writeln('};');

    return buffer.toString();
  }
}
