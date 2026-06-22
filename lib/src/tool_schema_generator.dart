import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tool_schema_generator/tool_schema_generator.dart';

import 'type_mapper.dart';

/// Scans top-level functions annotated with `@Tool()` and emits provider-shaped
/// LLM tool schemas plus a generated dispatch registry.
class ToolSchemaGenerator extends Generator {
  static final _toolTypeChecker = TypeChecker.typeNamed(
    Tool,
    inPackage: 'tool_schema_generator',
  );
  static final _describeTypeChecker = TypeChecker.typeNamed(
    Describe,
    inPackage: 'tool_schema_generator',
  );
  static final _injectTypeChecker = TypeChecker.typeNamed(
    Inject,
    inPackage: 'tool_schema_generator',
  );

  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final functions =
        <({TopLevelFunctionElement element, ConstantReader annotation})>[];

    for (final element in library.allElements) {
      if (element is! TopLevelFunctionElement) continue;
      if (!_toolTypeChecker.hasAnnotationOfExact(element)) continue;
      final annotation = _toolTypeChecker.firstAnnotationOfExact(element);
      if (annotation == null) continue;
      _validateInjectedParameters(element);
      functions.add((element: element, annotation: ConstantReader(annotation)));
    }

    if (functions.isEmpty) return '';
    _validateUniqueToolNames(functions);

    final typeMapper = TypeMapper();
    final output = StringBuffer();

    for (final fn in functions) {
      final formats = _readFormats(fn.annotation);
      output
        ..writeln(
          _generateSchemasForFunction(
            fn.element,
            fn.annotation,
            formats,
            typeMapper: typeMapper,
          ),
        )
        ..writeln();
    }

    output.writeln(_generateDispatcher(functions, typeMapper));
    return output.toString();
  }

  String _generateDispatcher(
    List<({TopLevelFunctionElement element, ConstantReader annotation})>
    functions,
    TypeMapper typeMapper,
  ) {
    final buffer = StringBuffer();
    final enumHelperNeeded = <String>{};
    final classHelpers = <String, String>{};

    for (final fn in functions) {
      for (final param in fn.element.formalParameters) {
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

    for (final fn in functions) {
      final toolName =
          fn.annotation.peek('name')?.stringValue ?? fn.element.name!;
      final dartName = fn.element.name;
      buffer.writeln("  /// Tool definition for [$dartName].");
      buffer.writeln("  ToolDefinition get $dartName => this['$toolName']!;");
    }

    buffer.writeln('}');
    buffer.writeln();

    final toolsBuffer = StringBuffer();
    for (final fn in functions) {
      final toolName =
          fn.annotation.peek('name')?.stringValue ?? fn.element.name!;
      final description =
          fn.annotation.peek('description')?.stringValue ??
          _extractDocComment(fn.element);
      final paramVarName = '${fn.element.name}ParametersSchema';

      final formats = _readFormats(fn.annotation);
      final formatsListLiteral =
          'const [${formats.map((f) => 'SchemaFormat.${f.name}').join(', ')}]';

      toolsBuffer.writeln('  ToolDefinition(');
      toolsBuffer.writeln("    name: '$toolName',");
      toolsBuffer.writeln("    description: '${_escapeString(description)}',");
      toolsBuffer.writeln('    parametersSchema: $paramVarName,');
      toolsBuffer.writeln('    formats: $formatsListLiteral,');
      toolsBuffer.writeln('    handler: (JsonObject args) async {');

      final positionalArgs = <String>[];
      final namedArgs = <String>[];
      for (final param in fn.element.formalParameters) {
        final paramName = param.name;
        if (paramName == null) continue;
        final expr = typeMapper.generateArgParser(
          param.type,
          paramName,
          defaultCode: param.defaultValueCode,
          isRequired: param.isRequiredPositional || param.isRequiredNamed,
        );
        if (param.isNamed) {
          namedArgs.add('$paramName: $expr');
        } else {
          positionalArgs.add(expr);
        }
      }
      final allArgs = [...positionalArgs, ...namedArgs].join(', ');
      toolsBuffer.writeln('      return ${fn.element.name}($allArgs);');
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

  String _generateSchemasForFunction(
    TopLevelFunctionElement functionElement,
    ConstantReader annotation,
    List<SchemaFormat> formats, {
    TypeMapper? typeMapper,
  }) {
    typeMapper ??= TypeMapper();

    final toolName =
        annotation.peek('name')?.stringValue ?? functionElement.name;
    final description =
        annotation.peek('description')?.stringValue ??
        _extractDocComment(functionElement);

    final propertiesBuffer = StringBuffer();
    final requiredParameterNames = <String>[];
    var isFirstProperty = true;

    for (final param in functionElement.formalParameters) {
      final paramName = param.name;
      if (paramName == null) continue;
      if (_hasAnnotation(param, _injectTypeChecker)) continue;

      if (!isFirstProperty) {
        propertiesBuffer.writeln(',');
      }
      isFirstProperty = false;

      final paramTypeSchema = typeMapper.mapType(param.type);
      final describeAnnotation = _findDescribeAnnotation(param);
      final schemaLiteral = describeAnnotation == null
          ? paramTypeSchema
          : _injectDescription(paramTypeSchema, describeAnnotation);
      propertiesBuffer.write("        '$paramName': $schemaLiteral");

      if (param.isRequiredPositional || param.isRequiredNamed) {
        requiredParameterNames.add(paramName);
      }
    }

    final requiredPart = requiredParameterNames.isNotEmpty
        ? "\n      'required': <String>[${requiredParameterNames.map((name) => "'$name'").join(', ')}],"
        : '';

    final parametersSchema = StringBuffer();
    parametersSchema.writeln('<String, Object?>{');
    parametersSchema.writeln("      'type': 'object',");
    parametersSchema.writeln("      'properties': <String, Object?>{");
    parametersSchema.write(propertiesBuffer.toString());
    parametersSchema.writeln();
    parametersSchema.writeln('      },');
    parametersSchema.write('      $requiredPart');
    parametersSchema.writeln();
    parametersSchema.write('    }');

    final buffer = StringBuffer();
    final paramVarName = '${functionElement.name}ParametersSchema';
    buffer.writeln('const $paramVarName = $parametersSchema;');
    buffer.writeln();

    final toolVarName = '${functionElement.name}ToolSchema';
    buffer.writeln('const $toolVarName = <String, Object?>{');
    buffer.writeln("  'type': 'function',");
    buffer.writeln("  'function': <String, Object?>{");
    buffer.writeln("    'name': '$toolName',");
    buffer.writeln("    'description': '${_escapeString(description)}',");
    buffer.writeln("    'parameters': $paramVarName,");
    buffer.writeln('  },');
    buffer.writeln('};');

    return buffer.toString();
  }

  String _extractDocComment(Element element) {
    final rawComment = element.documentationComment;
    if (rawComment == null || rawComment.isEmpty) {
      return '';
    }

    final lines = rawComment.split('\n').map((line) {
      var trimmed = line.trimLeft();
      if (trimmed.startsWith('/// ')) {
        return trimmed.substring(4);
      } else if (trimmed.startsWith('///')) {
        return trimmed.substring(3);
      }
      return trimmed;
    }).toList();

    return lines.join('\n');
  }

  String? _findDescribeAnnotation(FormalParameterElement param) {
    final annotationValue = _findAnnotation(param, _describeTypeChecker);
    return annotationValue?.getField('description')?.toStringValue();
  }

  void _validateInjectedParameters(TopLevelFunctionElement function) {
    for (final param in function.formalParameters) {
      if (!_hasAnnotation(param, _injectTypeChecker)) continue;

      final name = param.name ?? '<unnamed>';
      final parameterLabel = '${function.name}.$name';

      if (!param.isNamed) {
        throw InvalidGenerationSourceError(
          '@Inject() can only be used on named parameters.',
          element: param,
          todo: 'Move "$name" into the named parameter list.',
        );
      }

      if (param.isRequiredNamed) {
        throw InvalidGenerationSourceError(
          '@Inject() parameters must not be required.',
          element: param,
          todo: 'Make "$parameterLabel" nullable or give it a default value.',
        );
      }

      final hasDefault =
          param.defaultValueCode != null && param.defaultValueCode!.isNotEmpty;
      final isNullable =
          param.type.nullabilitySuffix == NullabilitySuffix.question;
      if (!hasDefault && !isNullable) {
        throw InvalidGenerationSourceError(
          '@Inject() parameters must be nullable or have a default value.',
          element: param,
          todo: 'Make "$parameterLabel" nullable or give it a default value.',
        );
      }
    }
  }

  void _validateUniqueToolNames(
    List<({TopLevelFunctionElement element, ConstantReader annotation})>
    functions,
  ) {
    final seen = <String, TopLevelFunctionElement>{};

    for (final fn in functions) {
      final toolName =
          fn.annotation.peek('name')?.stringValue ?? fn.element.name!;
      final previous = seen[toolName];
      if (previous != null) {
        throw InvalidGenerationSourceError(
          'Duplicate tool name "$toolName".',
          element: fn.element,
          todo:
              'Give "${fn.element.name}" or "${previous.name}" a unique @Tool(name: ...).',
        );
      }
      seen[toolName] = fn.element;
    }
  }

  bool _hasAnnotation(FormalParameterElement param, TypeChecker typeChecker) =>
      _findAnnotation(param, typeChecker) != null;

  DartObject? _findAnnotation(
    FormalParameterElement param,
    TypeChecker typeChecker,
  ) {
    for (final metadata in param.metadata.annotations) {
      final annotationValue = metadata.computeConstantValue();
      if (annotationValue == null) continue;

      final annotationType = annotationValue.type;
      if (annotationType != null && typeChecker.isExactlyType(annotationType)) {
        return annotationValue;
      }
    }
    return null;
  }

  String _injectDescription(String schemaLiteral, String description) {
    return schemaLiteral.replaceFirst(
      '<String, Object?>{',
      "<String, Object?>{'description': '${_escapeString(description)}', ",
    );
  }

  String _escapeString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');
  }

  List<SchemaFormat> _readFormats(ConstantReader annotation) {
    final values = annotation.peek('formats')?.listValue;
    if (values == null) return SchemaFormat.values;

    final formats = <SchemaFormat>{};
    for (final value in values) {
      final index = value.getField('index')?.toIntValue();
      if (index != null && index >= 0 && index < SchemaFormat.values.length) {
        formats.add(SchemaFormat.values[index]);
      }
    }
    return formats.toList();
  }
}
