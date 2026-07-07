import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'schema_spec.dart';

/// Maps Dart types to provider-compatible JSON object schema representations.
class TypeMapper {
  final _schemaProcessingStack = <ClassElement>{};

  /// Converts a [DartType] to an internal JSON Schema representation.
  ///
  /// Handles:
  /// - Primitive types (`String`, `int`, `double`, `num`, `bool`)
  /// - `List<T>` -> `{"type": "array", "items": <T schema>}`
  /// - `Map<String, T>` -> `{"type": "object"}`
  /// - Enum types -> `{"type": "string", "enum": [...]}`
  /// - Custom classes -> recursive `{"type": "object", "properties": {...}}`
  /// - Nullable types -> marks the schema nullable. Non-strict rendering emits
  ///   `"nullable": true`; strict rendering emits JSON Schema type unions.
  SchemaSpec mapType(DartType type) {
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    final coreSchema = _mapCoreType(type);

    return isNullable ? coreSchema.copyWith(isNullable: true) : coreSchema;
  }

  String? strictIncompatibilityReason(DartType type) =>
      _strictIncompatibilityReason(type, <ClassElement>{});

  SchemaSpec _mapCoreType(DartType type) {
    final element = type.element;

    if (type is VoidType || type is DynamicType) {
      return const StringSchemaSpec();
    }

    switch (_baseTypeName(type)) {
      case 'String':
        return const StringSchemaSpec();
      case 'int':
        return const IntegerSchemaSpec();
      case 'double':
        return const NumberSchemaSpec();
      case 'num':
        return const NumberSchemaSpec();
      case 'bool':
        return const BooleanSchemaSpec();
    }

    if (type.isDartCoreList && type is InterfaceType) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        return ArraySchemaSpec(items: mapType(typeArgs.first));
      }
      return const ArraySchemaSpec(items: null);
    }

    if (type.isDartCoreMap) {
      return const ObjectSchemaSpec();
    }

    if (element is EnumElement) {
      return EnumSchemaSpec(
        values: element.fields
            .where((field) => field.isEnumConstant)
            .map((field) => field.name)
            .nonNulls
            .toList(),
      );
    }

    if (element is ClassElement && type is InterfaceType) {
      return _mapClassType(element);
    }

    return const StringSchemaSpec();
  }

  ObjectSchemaSpec _mapClassType(ClassElement classElement) {
    final className = classElement.name;

    if (className == null || _schemaProcessingStack.contains(classElement)) {
      return ObjectSchemaSpec(
        description: '${className ?? 'unknown'} (circular reference)',
      );
    }

    _schemaProcessingStack.add(classElement);
    try {
      final constructor =
          classElement.unnamedConstructor ??
          classElement.constructors.firstOrNull;
      if (constructor == null) return const ObjectSchemaSpec();

      final properties = <String, SchemaSpec>{};
      final requiredParams = <String>[];

      for (final param in constructor.formalParameters) {
        final paramName = param.name;
        if (paramName == null) continue;

        properties[paramName] = mapType(param.type);
        if (param.isRequired) requiredParams.add(paramName);
      }

      return ObjectSchemaSpec(properties: properties, required: requiredParams);
    } finally {
      _schemaProcessingStack.remove(classElement);
    }
  }

  String? _strictIncompatibilityReason(
    DartType type,
    Set<ClassElement> processingStack,
  ) {
    if (type is DynamicType) {
      return 'dynamic values do not have a statically describable JSON schema.';
    }
    if (type is VoidType) {
      return 'void values do not have a JSON schema.';
    }
    if (type.isDartCoreMap) {
      return 'map values are free-form objects and cannot be closed with additionalProperties: false.';
    }

    if (type.isDartCoreList && type is InterfaceType) {
      if (type.typeArguments.isEmpty) {
        return 'raw lists do not declare an item schema.';
      }
      return _strictIncompatibilityReason(
        type.typeArguments.first,
        processingStack,
      );
    }

    final element = type.element;
    if (element is! ClassElement || type is! InterfaceType) return null;

    final libUri = element.library.uri.toString();
    if (libUri.startsWith('dart:')) return null;

    if (processingStack.contains(element)) {
      return 'recursive object types cannot be represented as finite strict schemas.';
    }

    final constructor =
        element.unnamedConstructor ?? element.constructors.firstOrNull;
    if (constructor == null) return null;

    processingStack.add(element);
    try {
      for (final constructorParam in constructor.formalParameters) {
        final reason = _strictIncompatibilityReason(
          constructorParam.type,
          processingStack,
        );
        if (reason != null) {
          final nestedName = constructorParam.name ?? '<unnamed>';
          return 'field "$nestedName" is not strict-compatible: $reason';
        }
      }
    } finally {
      processingStack.remove(element);
    }

    return null;
  }

  String _baseTypeName(DartType type) {
    final typeName = type.getDisplayString();
    return typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;
  }
}
