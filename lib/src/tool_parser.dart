import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:source_gen/source_gen.dart';
import 'package:tool_schema_generator/tool_schema_generator.dart';

import 'schema_spec.dart';
import 'tool_spec.dart';
import 'type_mapper.dart';

final class ToolParser {
  ToolParser({TypeMapper? typeMapper})
    : typeMapper = typeMapper ?? TypeMapper();

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

  final TypeMapper typeMapper;

  List<ToolSpec> parse(LibraryReader library) {
    final tools = <ToolSpec>[];

    for (final annotated in library.annotatedWithExact(_toolTypeChecker)) {
      final element = annotated.element;
      if (element is! TopLevelFunctionElement) {
        throw InvalidGenerationSourceError(
          '@Tool() can only be applied to top-level functions.',
          element: element,
          todo: 'Move @Tool() to a top-level function declaration.',
        );
      }

      final reader = annotated.annotation;
      final parameters = _parseParameters(element);
      final properties = <String, SchemaSpec>{
        for (final param in parameters)
          if (param.schema != null) param.name: param.schema!,
      };
      final required = [
        for (final param in parameters)
          if (!param.isInjected && param.isRequired) param.name,
      ];
      final strict = reader.peek('strict')?.boolValue ?? false;
      if (strict) _validateStrictParameters(parameters);

      final parametersSchema = ObjectSchemaSpec(
        properties: properties,
        required: required,
      );

      tools.add(
        ToolSpec(
          element: element,
          name: reader.peek('name')?.stringValue ?? element.name!,
          description:
              reader.peek('description')?.stringValue ??
              _extractDocComment(element),
          formats: _readFormats(reader),
          parameters: parameters,
          parametersSchema: strict
              ? parametersSchema.toStrict()
              : parametersSchema,
          strict: strict,
        ),
      );
    }

    _validateUniqueToolNames(tools);
    return tools;
  }

  List<ParameterSpec> _parseParameters(TopLevelFunctionElement function) {
    final parameters = <ParameterSpec>[];

    for (final param in function.formalParameters) {
      final paramName = param.name;
      if (paramName == null) continue;

      final isInjected = _hasAnnotation(param, _injectTypeChecker);
      if (isInjected) _validateInjectedParameter(function, param);

      final schema = isInjected ? null : _parameterSchema(param);

      parameters.add(
        ParameterSpec(
          element: param,
          name: paramName,
          isRequired: param.isRequiredPositional || param.isRequiredNamed,
          isNamed: param.isNamed,
          isInjected: isInjected,
          defaultValueCode: param.defaultValueCode,
          schema: schema,
        ),
      );
    }

    return parameters;
  }

  SchemaSpec _parameterSchema(FormalParameterElement param) {
    final describeAnnotation = _findDescribeAnnotation(param);
    final mappedSchema = typeMapper.mapType(param.type);
    return describeAnnotation == null
        ? mappedSchema
        : mappedSchema.withDescription(describeAnnotation);
  }

  void _validateStrictParameters(List<ParameterSpec> parameters) {
    for (final param in parameters.where((p) => !p.isInjected)) {
      final reason = typeMapper.strictIncompatibilityReason(param.element.type);
      if (reason == null) continue;

      throw InvalidGenerationSourceError(
        'Parameter "${param.name}" cannot be used with @Tool(strict: true): $reason',
        element: param.element,
        todo:
            'Use a concrete Dart type with statically known fields, or remove strict: true.',
      );
    }
  }

  void _validateInjectedParameter(
    TopLevelFunctionElement function,
    FormalParameterElement param,
  ) {
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

  void _validateUniqueToolNames(List<ToolSpec> tools) {
    final seen = <String, TopLevelFunctionElement>{};

    for (final tool in tools) {
      final previous = seen[tool.name];
      if (previous != null) {
        throw InvalidGenerationSourceError(
          'Duplicate tool name "${tool.name}".',
          element: tool.element,
          todo:
              'Give "${tool.element.name}" or "${previous.name}" a unique @Tool(name: ...).',
        );
      }
      seen[tool.name] = tool.element;
    }
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
