import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Maps Dart types to JSON Schema Draft 2020-12 compatible type representations.
///
/// Returns a Dart source string that represents a `Map<String, dynamic>` literal
/// suitable for embedding in generated code.
class TypeMapper {
  /// Set of class types already being processed, used to prevent infinite
  /// recursion when a class references itself.
  final Set<String> _processingStack = {};

  /// Converts a [DartType] to a JSON Schema map literal string.
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
        '<String, dynamic>{',
        "<String, dynamic>{'nullable': true, ",
      );
    }

    return coreSchema;
  }

  String _mapCoreType(DartType type) {
    // Unwrap nullable for matching
    final element = type.element;

    // Check for void / dynamic
    if (type is VoidType || type is DynamicType) {
      return "<String, dynamic>{'type': 'string'}";
    }

    // Check primitive types by name
    final typeName = type.getDisplayString();
    final baseTypeName = typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;

    switch (baseTypeName) {
      case 'String':
        return "<String, dynamic>{'type': 'string'}";
      case 'int':
        return "<String, dynamic>{'type': 'integer'}";
      case 'double':
        return "<String, dynamic>{'type': 'number'}";
      case 'num':
        return "<String, dynamic>{'type': 'number'}";
      case 'bool':
        return "<String, dynamic>{'type': 'boolean'}";
    }

    // Check for List<T>
    if (type.isDartCoreList && type is InterfaceType) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        final itemsSchema = mapType(typeArgs.first);
        return "<String, dynamic>{'type': 'array', 'items': $itemsSchema}";
      }
      return "<String, dynamic>{'type': 'array'}";
    }

    // Check for Map<String, T>
    if (type.isDartCoreMap) {
      return "<String, dynamic>{'type': 'object'}";
    }

    // Check for enum types
    if (element is EnumElement) {
      final enumValues = element.fields
          .where((field) => field.isEnumConstant)
          .map((field) => "'${field.name}'")
          .join(', ');
      return "<String, dynamic>{'type': 'string', 'enum': <String>[$enumValues]}";
    }

    // Check for custom class types (nested objects)
    if (element is ClassElement && type is InterfaceType) {
      return _mapClassType(element);
    }

    // Fallback
    return "<String, dynamic>{'type': 'string'}";
  }

  /// Maps a [ClassElement] to a JSON Schema "object" type with properties
  /// derived from the class's constructor parameters.
  String _mapClassType(ClassElement classElement) {
    final className = classElement.name;

    // Prevent infinite recursion for self-referencing types
    if (className == null || _processingStack.contains(className)) {
      return "<String, dynamic>{'type': 'object', 'description': '${className ?? 'unknown'} (circular reference)'}";
    }

    _processingStack.add(className);

    try {
      // Find the unnamed constructor or the first constructor
      final constructor =
          classElement.unnamedConstructor ??
          classElement.constructors.firstOrNull;

      if (constructor == null) {
        return "<String, dynamic>{'type': 'object'}";
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

      return "<String, dynamic>{'type': 'object', 'properties': <String, dynamic>{$propertiesBuffer}$requiredPart}";
    } finally {
      _processingStack.remove(className);
    }
  }
}
