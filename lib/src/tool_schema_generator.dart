import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

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

    output.writeln(_generateDispatcher(tools, typeMapper));
    return output.toString();
  }

  String _generateDispatcher(List<ToolSpec> tools, TypeMapper typeMapper) {
    final buffer = StringBuffer();
    final enumHelperNeeded = <String>{};
    final classHelpers = <String, String>{};

    for (final tool in tools) {
      for (final param in tool.element.formalParameters) {
        final element = param.type.element;
        if (element is EnumElement && element.name != null) {
          enumHelperNeeded.add(element.name!);
        }
        if (element is ClassElement && element.name != null) {
          final name = element.name!;
          final libUri = element.library.uri.toString();
          if (!libUri.startsWith('dart:') && !classHelpers.containsKey(name)) {
            final src = typeMapper.generateClassParser(element);
            if (src != null) classHelpers[name] = src;
          }
        }
      }
    }

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
        "  ToolDefinition get $dartName => this['${_escapeString(tool.name)}']!;",
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
      toolsBuffer.writeln("    name: '${_escapeString(tool.name)}',");
      toolsBuffer.writeln(
        "    description: '${_escapeString(tool.description)}',",
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
        final expr = typeMapper.generateArgParser(
          param.element.type,
          param.name,
          defaultCode: param.defaultValueCode,
          isRequired: param.isRequired,
        );
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

    if (enumHelperNeeded.isNotEmpty || classHelpers.isNotEmpty) {
      buffer.writeln('// ignore: unused_element');
      buffer.writeln('T? _parseEnum<T extends Enum>(');
      buffer.writeln('  List<T> values,');
      buffer.writeln('  String? raw,');
      buffer.writeln('  String field,');
      buffer.writeln(') {');
      buffer.writeln('  if (raw == null) return null;');
      buffer.writeln('  for (final value in values) {');
      buffer.writeln('    if (value.name == raw) return value;');
      buffer.writeln('  }');
      buffer.writeln('  throw InvalidToolArgumentException(');
      buffer.writeln('    field: field,');
      buffer.writeln(
        "    message: 'Invalid enum value \"\$raw\" for \"\$field\".',",
      );
      buffer.writeln('    expected: values.map((e) => e.name).toList(),');
      buffer.writeln('    actual: raw,');
      buffer.writeln('  );');
      buffer.writeln('}');
      buffer.writeln();
    }

    for (final src in classHelpers.values) {
      buffer.writeln('// ignore: unused_element');
      buffer.writeln(src);
    }

    return buffer.toString();
  }

  String _generateSchemasForTool(ToolSpec tool) {
    final buffer = StringBuffer();
    final paramVarName = '${tool.element.name}ParametersSchema';
    buffer.writeln(
      'const $paramVarName = ${tool.parametersSchema.toDartSource()};',
    );
    buffer.writeln();

    final toolVarName = '${tool.element.name}ToolSchema';
    buffer.writeln('const $toolVarName = <String, Object?>{');
    buffer.writeln("  'type': 'function',");
    buffer.writeln("  'function': <String, Object?>{");
    buffer.writeln("    'name': '${_escapeString(tool.name)}',");
    buffer.writeln("    'description': '${_escapeString(tool.description)}',");
    buffer.writeln("    'parameters': $paramVarName,");
    if (tool.strict) {
      buffer.writeln("    'strict': true,");
    }
    buffer.writeln('  },');
    buffer.writeln('};');

    return buffer.toString();
  }

  String _escapeString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');
  }
}
