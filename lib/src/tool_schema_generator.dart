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
    // Collected per-function data for schema + dispatcher generation
    final functions = <({
      TopLevelFunctionElement element,
      ConstantReader annotation,
    })>[];

    for (final element in library.allElements) {
      if (element is! TopLevelFunctionElement) continue;
      if (!_toolTypeChecker.hasAnnotationOfExact(element)) continue;
      final annotation = _toolTypeChecker.firstAnnotationOfExact(element);
      if (annotation == null) continue;
      functions.add((element: element, annotation: ConstantReader(annotation)));
    }

    if (functions.isEmpty) return '';

    final typeMapper = TypeMapper();
    final output = StringBuffer();
    final schemaVarNames = <String>[];

    // ── Schemas ──────────────────────────────────────────────────────────────
    for (final fn in functions) {
      final schemaCode = _generateSchemaForFunction(
        fn.element,
        fn.annotation,
        typeMapper: typeMapper,
      );
      final schemaVarName = '${fn.element.name}ToolSchema';
      schemaVarNames.add(schemaVarName);
      output
        ..writeln(schemaCode)
        ..writeln();
    }

    // Aggregate list
    output.writeln('const allToolSchemas = <Map<String, dynamic>>[');
    for (final name in schemaVarNames) {
      output.writeln('  $name,');
    }
    output.writeln('];');
    output.writeln();

    // ── Dispatcher ───────────────────────────────────────────────────────────
    output.writeln(_generateDispatcher(functions, typeMapper));

    return output.toString();
  }

  /// Generates the `toolRegistry` constant and all required private helpers.
  String _generateDispatcher(
    List<({TopLevelFunctionElement element, ConstantReader annotation})> functions,
    TypeMapper typeMapper,
  ) {
    final buffer = StringBuffer();

    // Collect which enum / class types need helpers (deduplicated by name)
    final enumHelperNeeded = <String>{};
    final classHelpers = <String, String>{}; // className → generated source

    for (final fn in functions) {
      for (final param in fn.element.formalParameters) {
        final element = param.type.element;
        if (element is EnumElement && element.name != null) {
          enumHelperNeeded.add(element.name!);
        }
        if (element is ClassElement && element.name != null) {
          final name = element.name!;
          // Only generate helpers for user-defined classes, not SDK types
          final libUri = element.library.uri.toString();
          final isSdkType = libUri.startsWith('dart:');
          if (!isSdkType && !classHelpers.containsKey(name)) {
            final src = typeMapper.generateClassParser(element);
            if (src != null) classHelpers[name] = src;
          }
        }
      }
    }

    // ── toolRegistry ─────────────────────────────────────────────────────────
    buffer.writeln(
      '/// Maps tool names to handlers. Pass to your LLM agent loop.',
    );
    buffer.writeln('final toolRegistry = ToolRegistry({');

    for (final fn in functions) {
      final toolName =
          fn.annotation.peek('name')?.stringValue ?? fn.element.name;
      buffer.writeln("  '$toolName': (Map<String, dynamic> args) async {");

      // Build argument expressions
      final positionalArgs = <String>[];
      final namedArgs = <String>[];

      for (final param in fn.element.formalParameters) {
        final paramName = param.name;
        if (paramName == null) continue;

        final expr = typeMapper.generateArgParser(
          param.type,
          paramName,
          defaultCode: param.defaultValueCode,
        );

        if (param.isNamed) {
          namedArgs.add('$paramName: $expr');
        } else {
          positionalArgs.add(expr);
        }
      }

      final allArgs = [...positionalArgs, ...namedArgs].join(', ');
      buffer.writeln('    return ${fn.element.name}($allArgs);');
      buffer.writeln('  },');
    }

    buffer.writeln('});');
    buffer.writeln();

    // ── Private helpers ───────────────────────────────────────────────────────
    if (enumHelperNeeded.isNotEmpty) {
      buffer.writeln(
        '// ignore: unused_element',
      );
      buffer.writeln(
        'T _parseEnum<T extends Enum>(List<T> values, String? raw) =>',
      );
      buffer.writeln(
        "    values.firstWhere((e) => e.name == raw, orElse: () => values.first);",
      );
      buffer.writeln();
    }

    for (final src in classHelpers.values) {
      buffer.writeln('// ignore: unused_element');
      buffer.writeln(src);
    }

    return buffer.toString();
  }

  /// Generates a `const Map<String, dynamic>` schema for a single
  /// `@Tool()`-annotated function.
  String _generateSchemaForFunction(
    TopLevelFunctionElement functionElement,
    ConstantReader annotation, {
    TypeMapper? typeMapper,
  }) {
    typeMapper ??= TypeMapper();

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
