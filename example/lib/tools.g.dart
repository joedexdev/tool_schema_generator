// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tools.dart';

// **************************************************************************
// ToolSchemaGenerator
// **************************************************************************

const getWeatherParametersSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'city': <String, Object?>{
      'description': 'The name of the city to look up',
      'type': 'string',
    },
    'unit': <String, Object?>{
      'description': 'The unit for temperature values',
      'type': 'string',
      'enum': <String>['celsius', 'fahrenheit', 'kelvin'],
    },
  },
  'required': <String>['city'],
};

const getWeatherToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'getWeather',
    'description':
        'Gets the current weather for a given city.\n\nReturns temperature, humidity, and wind conditions\nfor the requested location.',
    'parameters': getWeatherParametersSchema,
  },
};

const searchProductsParametersSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'query': <String, Object?>{
      'description': 'The search query',
      'type': 'string',
    },
    'maxResults': <String, Object?>{
      'description': 'Maximum number of results',
      'type': 'integer',
    },
    'includeOutOfStock': <String, Object?>{'nullable': true, 'type': 'boolean'},
  },
  'required': <String>['query', 'maxResults'],
};

const searchProductsToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'search_products',
    'description': 'Searches for products matching a query string.',
    'parameters': searchProductsParametersSchema,
  },
};

const findNearbyPlacesParametersSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'location': <String, Object?>{
      'description': 'The center point to search around',
      'type': 'object',
      'properties': <String, Object?>{
        'latitude': <String, Object?>{'type': 'number'},
        'longitude': <String, Object?>{'type': 'number'},
      },
      'required': <String>['latitude', 'longitude'],
    },
    'radiusKm': <String, Object?>{
      'description': 'Search radius in kilometers',
      'type': 'number',
    },
    'category': <String, Object?>{
      'description': 'Category filter, e.g. restaurant, park',
      'nullable': true,
      'type': 'string',
    },
  },
  'required': <String>['location', 'radiusKm'],
};

const findNearbyPlacesToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'findNearbyPlaces',
    'description':
        'Finds nearby places of interest based on geographic coordinates.',
    'parameters': findNearbyPlacesParametersSchema,
  },
};

const sendEmailParametersSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'to': <String, Object?>{
      'description': 'Recipient email address',
      'type': 'string',
    },
    'subject': <String, Object?>{
      'description': 'Email subject line',
      'type': 'string',
    },
    'body': <String, Object?>{
      'description': 'Email body content',
      'type': 'string',
    },
    'cc': <String, Object?>{
      'description': 'CC recipients for the mail',
      'nullable': true,
      'type': 'array',
      'items': <String, Object?>{'type': 'string'},
    },
  },
  'required': <String>['to', 'subject', 'body'],
};

const sendEmailToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'sendEmail',
    'description': 'Composes and sends an email message.',
    'parameters': sendEmailParametersSchema,
  },
};

/// Generated registry - provides named schema getters and tool dispatch.
final class _ToolRegistry extends ToolRegistry {
  _ToolRegistry(super.tools);

  /// Tool definition for [getWeather].
  ToolDefinition get getWeather => this['getWeather']!;

  /// Tool definition for [searchProducts].
  ToolDefinition get searchProducts => this['search_products']!;

  /// Tool definition for [findNearbyPlaces].
  ToolDefinition get findNearbyPlaces => this['findNearbyPlaces']!;

  /// Tool definition for [sendEmail].
  ToolDefinition get sendEmail => this['sendEmail']!;
}

/// The generated tool registry for this file.
/// Use [toolRegistry.encode] to get provider-formatted schemas,
/// and [toolRegistry.call] to dispatch model tool calls.
final toolRegistry = _ToolRegistry([
  ToolDefinition(
    name: 'getWeather',
    description:
        'Gets the current weather for a given city.\n\nReturns temperature, humidity, and wind conditions\nfor the requested location.',
    parametersSchema: getWeatherParametersSchema,
    formats: const [
      SchemaFormat.openAi,
      SchemaFormat.anthropic,
      SchemaFormat.gemini,
    ],
    handler: (JsonObject args) async {
      return getWeather(
        ToolRegistry.getRequiredArg<String>(args, 'city'),
        unit:
            _parseEnum(
              TemperatureUnit.values,
              ToolRegistry.getOptionalArg<String>(args, 'unit'),
              'unit',
            ) ??
            .celsius,
      );
    },
  ),
  ToolDefinition(
    name: 'search_products',
    description: 'Searches for products matching a query string.',
    parametersSchema: searchProductsParametersSchema,
    formats: const [
      SchemaFormat.openAi,
      SchemaFormat.anthropic,
      SchemaFormat.gemini,
    ],
    handler: (JsonObject args) async {
      return searchProducts(
        ToolRegistry.getRequiredArg<String>(args, 'query'),
        ToolRegistry.getRequiredArg<int>(args, 'maxResults'),
        includeOutOfStock: ToolRegistry.getOptionalArg<bool>(
          args,
          'includeOutOfStock',
        ),
      );
    },
  ),
  ToolDefinition(
    name: 'findNearbyPlaces',
    description:
        'Finds nearby places of interest based on geographic coordinates.',
    parametersSchema: findNearbyPlacesParametersSchema,
    formats: const [
      SchemaFormat.openAi,
      SchemaFormat.anthropic,
      SchemaFormat.gemini,
    ],
    handler: (JsonObject args) async {
      return findNearbyPlaces(
        _parseGeoLocation(ToolRegistry.getRequiredObjectArg(args, 'location')),
        ToolRegistry.getRequiredDoubleArg(args, 'radiusKm'),
        category: ToolRegistry.getOptionalArg<String>(args, 'category'),
      );
    },
  ),
  ToolDefinition(
    name: 'sendEmail',
    description: 'Composes and sends an email message.',
    parametersSchema: sendEmailParametersSchema,
    formats: const [SchemaFormat.anthropic, SchemaFormat.openAi],
    handler: (JsonObject args) async {
      return sendEmail(
        ToolRegistry.getRequiredArg<String>(args, 'to'),
        ToolRegistry.getRequiredArg<String>(args, 'subject'),
        ToolRegistry.getRequiredArg<String>(args, 'body'),
        cc: ToolRegistry.getOptionalListArg<String>(args, 'cc'),
      );
    },
  ),
]);

// ignore: unused_element
T? _parseEnum<T extends Enum>(List<T> values, String? raw, String field) {
  if (raw == null) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw InvalidToolArgumentException(
    field: field,
    message: 'Invalid enum value "$raw" for "$field".',
    expected: values.map((e) => e.name).toList(),
    actual: raw,
  );
}

// ignore: unused_element
GeoLocation _parseGeoLocation(JsonObject m) => GeoLocation(
  latitude: ToolRegistry.getRequiredDoubleArg(m, 'latitude'),
  longitude: ToolRegistry.getRequiredDoubleArg(m, 'longitude'),
);
