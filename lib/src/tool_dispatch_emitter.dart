import 'dart:collection';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'dart_source.dart';
import 'tool_spec.dart';

/// Emits generated dispatcher expressions and helper parsers.
final class ToolDispatchEmitter {
  ToolDispatchEmitter({LibraryElement? library}) : _library = library;

  final LibraryElement? _library;

  final _classHelperNames = LinkedHashMap<ClassElement, String>.identity();
  final _classHelperTypes = HashMap<ClassElement, InterfaceType>.identity();
  final _helperBaseCounts = <String, int>{};
  final _enumHelpersNeeded = LinkedHashSet<EnumElement>.identity();

  String argumentExpression(
    ParameterSpec param, {
    String sourceName = 'args',
  }) => _generateArgParser(
    param.element.type,
    param.name,
    defaultCode: _visibleDefaultCode(param.element),
    isRequired: param.isRequired,
    sourceName: sourceName,
  );

  List<String> get helperSources {
    final classSources = _classParserSources;
    return [
      if (_enumHelpersNeeded.isNotEmpty) _enumParserSource,
      ...classSources,
    ];
  }

  List<String> get _classParserSources {
    final emitted = HashSet<ClassElement>.identity();
    final sources = <String>[];

    while (emitted.length < _classHelperNames.length) {
      for (final element in List<ClassElement>.of(_classHelperNames.keys)) {
        if (!emitted.add(element)) continue;
        final source = _generateClassParser(element);
        if (source != null) sources.add(source);
      }
    }

    return sources;
  }

  String _generateArgParser(
    DartType type,
    String fieldName, {
    String? defaultCode,
    required bool isRequired,
    String sourceName = 'args',
  }) {
    final hasDefault = defaultCode != null && defaultCode.isNotEmpty;
    const accessor = 'ToolRegistry';
    final fieldLiteral = dartStringLiteral(fieldName);

    String readValue(String typeName) {
      if (hasDefault) {
        return '$accessor.getArgOrDefault<$typeName>($sourceName, $fieldLiteral, $defaultCode)';
      }
      if (isRequired) {
        return '$accessor.getRequiredArg<$typeName>($sourceName, $fieldLiteral)';
      }
      return '$accessor.getOptionalArg<$typeName>($sourceName, $fieldLiteral)';
    }

    if (type is VoidType || type is DynamicType) {
      if (hasDefault) return '$sourceName[$fieldLiteral] ?? $defaultCode';
      if (isRequired) {
        return '$accessor.getRequiredArg<Object?>($sourceName, $fieldLiteral)';
      }
      return '$sourceName[$fieldLiteral]';
    }

    switch (_baseTypeName(type)) {
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
          return '($accessor.getOptionalDoubleArg($sourceName, $fieldLiteral) ?? $defaultCode)';
        }
        if (isRequired) {
          return '$accessor.getRequiredDoubleArg($sourceName, $fieldLiteral)';
        }
        return '$accessor.getOptionalDoubleArg($sourceName, $fieldLiteral)';
    }

    final element = type.element;

    if (type.isDartCoreList && type is InterfaceType) {
      final typeArgs = type.typeArguments;
      if (typeArgs.isNotEmpty) {
        final itemType = typeArgs.first.getDisplayString();
        if (hasDefault) {
          return '($accessor.getOptionalListArg<$itemType>($sourceName, $fieldLiteral) ?? $defaultCode)';
        }
        if (isRequired) {
          return '$accessor.getRequiredListArg<$itemType>($sourceName, $fieldLiteral)';
        }
        return '$accessor.getOptionalListArg<$itemType>($sourceName, $fieldLiteral)';
      }
      if (hasDefault) {
        return '$accessor.getArgOrDefault<List<Object?>>($sourceName, $fieldLiteral, $defaultCode)';
      }
      if (isRequired) {
        return '$accessor.getRequiredArg<List<Object?>>($sourceName, $fieldLiteral)';
      }
      return '$accessor.getOptionalArg<List<Object?>>($sourceName, $fieldLiteral)';
    }

    if (type.isDartCoreMap) {
      if (hasDefault) {
        return '$accessor.getOptionalObjectArg($sourceName, $fieldLiteral) ?? $defaultCode';
      }
      if (isRequired) {
        return '$accessor.getRequiredObjectArg($sourceName, $fieldLiteral)';
      }
      return '$accessor.getOptionalObjectArg($sourceName, $fieldLiteral)';
    }

    if (element is EnumElement) {
      final enumName = element.name;
      if (enumName == null) {
        if (hasDefault) return '$sourceName[$fieldLiteral] ?? $defaultCode';
        if (isRequired) {
          return '$accessor.getRequiredArg<Object?>($sourceName, $fieldLiteral)';
        }
        return '$sourceName[$fieldLiteral]';
      }

      _enumHelpersNeeded.add(element);
      final enumReference = _visibleElementReference(element, enumName);
      final raw = hasDefault || !isRequired
          ? '$accessor.getOptionalArg<String>($sourceName, $fieldLiteral)'
          : '$accessor.getRequiredArg<String>($sourceName, $fieldLiteral)';
      if (hasDefault) {
        return '_parseEnum($enumReference.values, $raw, $fieldLiteral) ?? $defaultCode';
      }
      return '_parseEnum($enumReference.values, $raw, $fieldLiteral)';
    }

    if (element is ClassElement && type is InterfaceType) {
      final className = element.name;
      if (className == null) {
        if (hasDefault) return '$sourceName[$fieldLiteral] ?? $defaultCode';
        if (isRequired) {
          return '$accessor.getRequiredArg<Object?>($sourceName, $fieldLiteral)';
        }
        return '$sourceName[$fieldLiteral]';
      }

      final helperName = _helperNameFor(element, type);
      if (hasDefault) {
        return '($accessor.getOptionalObjectArg($sourceName, $fieldLiteral) != null ? $helperName($accessor.getRequiredObjectArg($sourceName, $fieldLiteral)) : $defaultCode)';
      }
      if (isRequired) {
        return '$helperName($accessor.getRequiredObjectArg($sourceName, $fieldLiteral))';
      }
      return '($accessor.getOptionalObjectArg($sourceName, $fieldLiteral) != null ? $helperName($accessor.getRequiredObjectArg($sourceName, $fieldLiteral)) : null)';
    }

    if (hasDefault) return '$sourceName[$fieldLiteral] ?? $defaultCode';
    if (isRequired) {
      return '$accessor.getRequiredArg<Object?>($sourceName, $fieldLiteral)';
    }
    return '$sourceName[$fieldLiteral]';
  }

  String _helperNameFor(ClassElement element, InterfaceType type) {
    final existing = _classHelperNames[element];
    if (existing != null) return existing;

    final className = element.name!;
    final base = '_parse${_capitalize(className)}';
    final next = (_helperBaseCounts[base] ?? 0) + 1;
    _helperBaseCounts[base] = next;

    final helperName = next == 1 ? base : '$base$next';
    _classHelperNames[element] = helperName;
    _classHelperTypes[element] = type;
    return helperName;
  }

  String? _generateClassParser(ClassElement classElement) {
    final helperName = _classHelperNames[classElement];
    final type = _classHelperTypes[classElement];
    if (helperName == null || type == null) return null;

    final constructor =
        classElement.unnamedConstructor ??
        classElement.constructors.firstOrNull;
    if (constructor == null) return null;

    final typeName = _visibleTypeReference(type);
    final buffer = StringBuffer();
    buffer.writeln('// ignore: unused_element');
    buffer.writeln('$typeName $helperName(JsonObject m) =>');
    buffer.write('    $typeName(');

    var first = true;
    for (final param in constructor.formalParameters) {
      if (!first) buffer.write(', ');
      first = false;
      final paramName = param.name ?? '';
      final expr = _generateArgParser(
        param.type,
        paramName,
        defaultCode: _visibleDefaultCode(param),
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

  String get _enumParserSource {
    final buffer = StringBuffer();
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
    return buffer.toString();
  }

  String _baseTypeName(DartType type) {
    final typeName = type.getDisplayString();
    return typeName.endsWith('?')
        ? typeName.substring(0, typeName.length - 1)
        : typeName;
  }

  String _rawTypeReference(InterfaceType type) {
    final typeName = _baseTypeName(type);
    final genericStart = typeName.indexOf('<');
    return genericStart == -1 ? typeName : typeName.substring(0, genericStart);
  }

  String _visibleTypeReference(InterfaceType type) {
    final rawType = _rawTypeReference(type);
    return _visibleElementReference(type.element, rawType);
  }

  String? _visibleDefaultCode(FormalParameterElement param) {
    final defaultCode = param.defaultValueCode;
    final element = param.type.element;
    final enumName = element?.name;
    if (defaultCode == null || element is! EnumElement || enumName == null) {
      return defaultCode;
    }

    if (!defaultCode.startsWith('$enumName.')) return defaultCode;
    return defaultCode.replaceFirst(
      '$enumName.',
      '${_visibleElementReference(element, enumName)}.',
    );
  }

  String _visibleElementReference(Element element, String name) {
    final library = _library;
    if (library == null) return name;
    if (identical(element.library, library)) return name;

    String? prefixedName;
    for (final import in library.firstFragment.libraryImports) {
      final prefix = import.prefix?.element.displayName;
      final lookupName = prefix == null || prefix.isEmpty
          ? name
          : '$prefix.$name';
      if (!_sameElement(import.namespace.get2(lookupName), element)) continue;

      if (prefix == null || prefix.isEmpty) return name;
      prefixedName ??= '$prefix.$name';
    }

    return prefixedName ?? name;
  }

  bool _sameElement(Element? a, Element b) =>
      a != null && (identical(a, b) || identical(a.baseElement, b.baseElement));

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
