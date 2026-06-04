import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Maps Dart types to provider-compatible JSON object schema representations.
///
/// Returns a Dart source string that represents a JSON object map literal
/// suitable for embedding in generated code.
class TypeMapper {
  /// Set of class types already being processed, used to prevent infinite
  /// recursion when a class references itself.
  final Set<String> _processingStack = {};

  /// Converts a [DartType] to a JSON object schema map literal string.
  ///
  /// Handles:
  /// - Primitive types (`String`, `int`, `double`, `num`, `bool`)
  /// - `List<T>` → `{"type": "array", "items": <T schema>}`
  /// - `Map<String, T>` → `{"type": "object"}`
  /// - Enum types → `{"type": "string", "enum": [...]}`
  /// - Custom classes → recursive `{"type": "object", "properties": {...}}`
  /// - Nullable types → adds `"nullable": true`
  String mapType(DartType type) {
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    final coreSchema = _mapCoreType(type);

    if (isNullable && !coreSchema.contains("'nullable': true")) {
      // Insert nullable flag into the schema map
      return coreSchema.replaceFirst(
        '<String, Object?>{',
        "<String, Object?>{'nullable': true, ",
      );
    }

    return coreSchema;
  }

  String _mapCoreType(DartType type) {
    // Unwrap nullable for matching
    final element = type.element;

    // Check for void / dynamic
    if (type is VoidType || type is DynamicType) {
      return "<String, Object?>{'type': 'string'}";
    }

    // Check primitive types by name
    final typeName = type.getDisplayString();
    final baseTypeName = typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;

    switch (baseTypeName) {
      case 'String':
        return "<String, Object?>{'type': 'string'}";
      case 'int':
        return "<String, Object?>{'type': 'integer'}";
      case 'double':
        return "<String, Object?>{'type': 'number'}";
      case 'num':
        return "<String, Object?>{'type': 'number'}";
      case 'bool':
        return "<String, Object?>{'type': 'boolean'}";
    }

    // Check for List<T>
    if (type.isDartCoreList && type is InterfaceType) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        final itemsSchema = mapType(typeArgs.first);
        return "<String, Object?>{'type': 'array', 'items': $itemsSchema}";
      }
      return "<String, Object?>{'type': 'array'}";
    }

    // Check for Map<String, T>
    if (type.isDartCoreMap) {
      return "<String, Object?>{'type': 'object'}";
    }

    // Check for enum types
    if (element is EnumElement) {
      final enumValues = element.fields
          .where((field) => field.isEnumConstant)
          .map((field) => "'${field.name}'")
          .join(', ');
      return "<String, Object?>{'type': 'string', 'enum': <String>[$enumValues]}";
    }

    // Check for custom class types (nested objects)
    if (element is ClassElement && type is InterfaceType) {
      return _mapClassType(element);
    }

    // Fallback
    return "<String, Object?>{'type': 'string'}";
  }

  /// Maps a [ClassElement] to a JSON Schema "object" type with properties
  /// derived from the class's constructor parameters.
  String _mapClassType(ClassElement classElement) {
    final className = classElement.name;

    // Prevent infinite recursion for self-referencing types
    if (className == null || _processingStack.contains(className)) {
      return "<String, Object?>{'type': 'object', 'description': '${className ?? 'unknown'} (circular reference)'}";
    }

    _processingStack.add(className);

    try {
      // Find the unnamed constructor or the first constructor
      final constructor =
          classElement.unnamedConstructor ??
          classElement.constructors.firstOrNull;

      if (constructor == null) {
        return "<String, Object?>{'type': 'object'}";
      }

      final propertiesBuffer = StringBuffer();
      final requiredParams = <String>[];
      var isFirstProperty = true;

      for (final param in constructor.formalParameters) {
        if (!isFirstProperty) {
          propertiesBuffer.write(', ');
        }
        isFirstProperty = false;

        final paramName = param.name;
        final paramSchema = mapType(param.type);
        propertiesBuffer.write("'$paramName': $paramSchema");

        if (param.isRequired) {
          requiredParams.add("'$paramName'");
        }
      }

      final requiredPart = requiredParams.isNotEmpty
          ? ", 'required': <String>[${requiredParams.join(', ')}]"
          : '';

      return "<String, Object?>{'type': 'object', 'properties': <String, Object?>{$propertiesBuffer}$requiredPart}";
    } finally {
      _processingStack.remove(className);
    }
  }

  // ---------------------------------------------------------------------------
  // Dispatcher code generation
  // ---------------------------------------------------------------------------

  /// Generates a Dart expression that safely extracts and casts the value for
  /// [fieldName] from an `args` map, for use in the generated dispatcher.
  ///
  /// [defaultCode] is the raw source string of the parameter's default value
  /// (e.g. `'celsius'` or `true`) as reported by the analyzer. When provided,
  /// a `?? defaultCode` fallback is appended for nullable/optional params.
  String generateArgParser(
    DartType type,
    String fieldName, {
    String? defaultCode,
    required bool isRequired,
    String sourceName = 'args',
  }) {
    final hasDefault = defaultCode != null && defaultCode.isNotEmpty;
    final accessor = "ToolRegistry";

    String readValue(String typeName) {
      if (hasDefault) {
        return '$accessor.getArgOrDefault<$typeName>($sourceName, \'$fieldName\', $defaultCode)';
      }
      if (isRequired) {
        return '$accessor.getRequiredArg<$typeName>($sourceName, \'$fieldName\')';
      }
      return '$accessor.getOptionalArg<$typeName>($sourceName, \'$fieldName\')';
    }

    if (type is VoidType || type is DynamicType) {
      if (hasDefault) return '$sourceName[\'$fieldName\'] ?? $defaultCode';
      if (isRequired) {
        return '$accessor.getRequiredArg<Object?>($sourceName, \'$fieldName\')';
      }
      return '$sourceName[\'$fieldName\']';
    }

    final typeName = type.getDisplayString();
    final baseTypeName = typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;
    switch (baseTypeName) {
      case 'String':
        return readValue('String');
      case 'int':
        return readValue('int');
      case 'bool':
        return readValue('bool');
      case 'num':
        return readValue('num');
      case 'double':
        if (hasDefault) {
          return '($accessor.getOptionalDoubleArg($sourceName, \'$fieldName\') ?? $defaultCode)';
        }
        if (isRequired) {
          return '$accessor.getRequiredDoubleArg($sourceName, \'$fieldName\')';
        }
        return '$accessor.getOptionalDoubleArg($sourceName, \'$fieldName\')';
    }

    final element = type.element;

    if (type.isDartCoreList && type is InterfaceType) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        final itemType = typeArgs.first.getDisplayString();
        if (hasDefault) {
          return '($accessor.getOptionalListArg<$itemType>($sourceName, \'$fieldName\') ?? $defaultCode)';
        }
        if (isRequired) {
          return '$accessor.getRequiredListArg<$itemType>($sourceName, \'$fieldName\')';
        }
        return '$accessor.getOptionalListArg<$itemType>($sourceName, \'$fieldName\')';
      }
      if (hasDefault) {
        return '$accessor.getArgOrDefault<List<Object?>>($sourceName, \'$fieldName\', $defaultCode)';
      }
      if (isRequired) {
        return '$accessor.getRequiredArg<List<Object?>>($sourceName, \'$fieldName\')';
      }
      return '$accessor.getOptionalArg<List<Object?>>($sourceName, \'$fieldName\')';
    }

    if (type.isDartCoreMap) {
      if (hasDefault) {
        return '$accessor.getOptionalObjectArg($sourceName, \'$fieldName\') ?? $defaultCode';
      }
      if (isRequired) {
        return '$accessor.getRequiredObjectArg($sourceName, \'$fieldName\')';
      }
      return '$accessor.getOptionalObjectArg($sourceName, \'$fieldName\')';
    }

    if (element is EnumElement) {
      final enumName = element.name;
      if (enumName == null) {
        if (hasDefault) return '$sourceName[\'$fieldName\'] ?? $defaultCode';
        if (isRequired) {
          return '$accessor.getRequiredArg<Object?>($sourceName, \'$fieldName\')';
        }
        return '$sourceName[\'$fieldName\']';
      }

      final raw = hasDefault || !isRequired
          ? '$accessor.getOptionalArg<String>($sourceName, \'$fieldName\')'
          : '$accessor.getRequiredArg<String>($sourceName, \'$fieldName\')';
      if (hasDefault) {
        return '_parseEnum($enumName.values, $raw, \'$fieldName\') ?? $defaultCode';
      }
      return '_parseEnum($enumName.values, $raw, \'$fieldName\')';
    }

    if (element is ClassElement) {
      final className = element.name;
      if (className == null) {
        if (hasDefault) return '$sourceName[\'$fieldName\'] ?? $defaultCode';
        if (isRequired) {
          return '$accessor.getRequiredArg<Object?>($sourceName, \'$fieldName\')';
        }
        return '$sourceName[\'$fieldName\']';
      }
      final cap = className[0].toUpperCase() + className.substring(1);
      final helperName = '_parse$cap';
      if (hasDefault) {
        return '($accessor.getOptionalObjectArg($sourceName, \'$fieldName\') != null ? $helperName($accessor.getRequiredObjectArg($sourceName, \'$fieldName\')) : $defaultCode)';
      }
      if (isRequired) {
        return '$helperName($accessor.getRequiredObjectArg($sourceName, \'$fieldName\'))';
      }
      return '($accessor.getOptionalObjectArg($sourceName, \'$fieldName\') != null ? $helperName($accessor.getRequiredObjectArg($sourceName, \'$fieldName\')) : null)';
    }

    if (hasDefault) return '$sourceName[\'$fieldName\'] ?? $defaultCode';
    if (isRequired) {
      return '$accessor.getRequiredArg<Object?>($sourceName, \'$fieldName\')';
    }
    return '$sourceName[\'$fieldName\']';
  }

  /// Generates the source for a `_parse<ClassName>` top-level helper that
  /// reconstructs a class from a raw [JsonObject].
  ///
  /// Returns `null` if the class has no usable constructor.
  String? generateClassParser(ClassElement classElement) {
    final className = classElement.name;
    if (className == null) return null;

    final constructor =
        classElement.unnamedConstructor ??
        classElement.constructors.firstOrNull;
    if (constructor == null) return null;

    final cap = className[0].toUpperCase() + className.substring(1);
    final helperName = '_parse$cap';
    final buffer = StringBuffer();
    buffer.writeln('$className $helperName(JsonObject m) =>');
    buffer.write('    $className(');

    var first = true;
    for (final param in constructor.formalParameters) {
      if (!first) buffer.write(', ');
      first = false;
      final paramName = param.name ?? '';
      // Reuse generateArgParser but with map variable `m` instead of `args`
      final expr = generateArgParser(
        param.type,
        paramName,
        defaultCode: param.defaultValueCode,
        isRequired: param.isRequired,
        sourceName: 'm',
      );
      if (param.isNamed) {
        buffer.write('$paramName: $expr');
      } else {
        buffer.write(expr);
      }
    }
    buffer.writeln(');');
    return buffer.toString();
  }
}
