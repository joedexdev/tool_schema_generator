import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tool_schema_generator/tool_schema_generator.dart';

import 'type_mapper.dart';

/// A [Generator] that scans all top-level functions annotated with `@Tool()`
/// in a library and emits `const Map<String, dynamic>` tool schema definitions.
///
/// For each annotated function it:
/// 1. Extracts the tool name (annotation override or function name)
/// 2. Extracts the description (annotation override or doc comment)
/// 3. Iterates parameters to build `properties` and `required` arrays
/// 4. Emits a `const <functionName>ToolSchema` variable
///
/// After processing all annotated functions in a library, it emits a
/// `const allToolSchemas` list aggregating every schema in the file.
class ToolSchemaGenerator extends Generator {
  static final _toolTypeChecker = TypeChecker.typeNamed(
    Tool,
    inPackage: 'tool_schema_generator',
  );
  static final _describeTypeChecker = TypeChecker.typeNamed(
    Describe,
    inPackage: 'tool_schema_generator',
  );

  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final schemaVariableNames = <String>[];
    final output = StringBuffer();

    // Iterate all top-level elements looking for @Tool() annotated functions
    for (final element in library.allElements) {
      if (element is! TopLevelFunctionElement) continue;
      if (!_toolTypeChecker.hasAnnotationOfExact(element)) continue;

      final annotation = _toolTypeChecker.firstAnnotationOfExact(element);
      if (annotation == null) continue;

      final constantReader = ConstantReader(annotation);
      final schemaCode = _generateSchemaForFunction(element, constantReader);

      final schemaVarName = '${element.name}ToolSchema';
      schemaVariableNames.add(schemaVarName);

      output.writeln(schemaCode);
      output.writeln();
    }

    // If no tools were found, return empty (no output)
    if (schemaVariableNames.isEmpty) {
      return '';
    }

    // Emit the aggregate list
    output.writeln('const allToolSchemas = <Map<String, dynamic>>[');
    for (final name in schemaVariableNames) {
      output.writeln('  $name,');
    }
    output.writeln('];');

    return output.toString();
  }

  /// Generates a `const Map<String, dynamic>` schema for a single
  /// `@Tool()`-annotated function.
  String _generateSchemaForFunction(
    TopLevelFunctionElement functionElement,
    ConstantReader annotation,
  ) {
    final typeMapper = TypeMapper();

    // --- Extract tool name ---
    final toolName =
        annotation.peek('name')?.stringValue ?? functionElement.name;

    // --- Extract description ---
    final descriptionOverride = annotation.peek('description')?.stringValue;
    final description =
        descriptionOverride ?? _extractDocComment(functionElement);

    // --- Build parameters schema ---
    final parameters = functionElement.formalParameters;
    final propertiesBuffer = StringBuffer();
    final requiredParameterNames = <String>[];
    var isFirstProperty = true;

    for (final param in parameters) {
      if (!isFirstProperty) {
        propertiesBuffer.writeln(',');
      }
      isFirstProperty = false;

      final paramName = param.name;
      if (paramName == null) continue;

      final paramTypeSchema = typeMapper.mapType(param.type);

      // Check for @Describe annotation on the parameter
      final describeAnnotation = _findDescribeAnnotation(param);

      if (describeAnnotation != null) {
        // Inject description into the type schema map
        final schemaWithDescription = _injectDescription(
          paramTypeSchema,
          describeAnnotation,
        );
        propertiesBuffer.write("        '$paramName': $schemaWithDescription");
      } else {
        propertiesBuffer.write("        '$paramName': $paramTypeSchema");
      }

      // Determine if required:
      // - Positional parameters are always required
      // - Named parameters are required only if they have the `required` keyword
      if (param.isRequiredPositional || param.isRequiredNamed) {
        requiredParameterNames.add(paramName);
      }
    }

    // --- Build the required array ---
    final requiredPart = requiredParameterNames.isNotEmpty
        ? "\n      'required': <String>[${requiredParameterNames.map((name) => "'$name'").join(', ')}],"
        : '';

    // --- Generate the schema variable name ---
    final schemaVarName = '${functionElement.name}ToolSchema';

    // --- Emit the const Map ---
    final buffer = StringBuffer();
    buffer.writeln('const $schemaVarName = <String, dynamic>{');
    buffer.writeln("  'type': 'function',");
    buffer.writeln("  'function': <String, dynamic>{");
    buffer.writeln("    'name': '$toolName',");
    buffer.writeln("    'description': '${_escapeString(description)}',");
    buffer.writeln("    'parameters': <String, dynamic>{");
    buffer.writeln("      'type': 'object',");
    buffer.writeln("      'properties': <String, dynamic>{");
    buffer.write(propertiesBuffer.toString());
    buffer.writeln();
    buffer.writeln('      },');
    buffer.write('      $requiredPart');
    buffer.writeln();
    buffer.writeln('    },');
    buffer.writeln('  },');
    buffer.writeln('};');

    return buffer.toString();
  }

  /// Extracts the doc comment from an element, stripping `///` prefixes.
  String _extractDocComment(Element element) {
    final rawComment = element.documentationComment;
    if (rawComment == null || rawComment.isEmpty) {
      return '';
    }

    // Strip /// prefixes and join lines
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

  /// Searches for a `@Describe` annotation on a [FormalParameterElement].
  String? _findDescribeAnnotation(FormalParameterElement param) {
    for (final metadata in param.metadata.annotations) {
      final annotationValue = metadata.computeConstantValue();
      if (annotationValue == null) continue;

      final annotationType = annotationValue.type;
      if (annotationType != null &&
          _describeTypeChecker.isExactlyType(annotationType)) {
        return annotationValue.getField('description')?.toStringValue();
      }
    }
    return null;
  }

  /// Injects a `'description'` key into a JSON Schema map literal string.
  String _injectDescription(String schemaLiteral, String description) {
    // Insert after the opening brace of the map
    return schemaLiteral.replaceFirst(
      '<String, dynamic>{',
      "<String, dynamic>{'description': '${_escapeString(description)}', ",
    );
  }

  /// Escapes single quotes, backslashes, and newlines for safe embedding
  /// in single-quoted Dart string literals.
  String _escapeString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');
  }
}
