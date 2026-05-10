// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tools.dart';

// **************************************************************************
// ToolSchemaGenerator
// **************************************************************************

const getWeatherToolSchema = <String, dynamic>{
  'type': 'function',
  'function': <String, dynamic>{
    'name': 'getWeather',
    'description':
        'Gets the current weather for a given city.\n\nReturns temperature, humidity, and wind conditions\nfor the requested location.',
    'parameters': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'city': <String, dynamic>{
          'description': 'The name of the city to look up',
          'type': 'string',
        },
        'unit': <String, dynamic>{
          'description': 'The unit for temperature values',
          'type': 'string',
          'enum': <String>['celsius', 'fahrenheit', 'kelvin'],
        },
      },

      'required': <String>['city'],
    },
  },
};

const searchProductsToolSchema = <String, dynamic>{
  'type': 'function',
  'function': <String, dynamic>{
    'name': 'search_products',
    'description': 'Searches for products matching a query string.',
    'parameters': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'query': <String, dynamic>{
          'description': 'The search query',
          'type': 'string',
        },
        'maxResults': <String, dynamic>{
          'description': 'Maximum number of results',
          'type': 'integer',
        },
        'includeOutOfStock': <String, dynamic>{
          'nullable': true,
          'type': 'boolean',
        },
      },

      'required': <String>['query', 'maxResults'],
    },
  },
};

const findNearbyPlacesToolSchema = <String, dynamic>{
  'type': 'function',
  'function': <String, dynamic>{
    'name': 'findNearbyPlaces',
    'description':
        'Finds nearby places of interest based on geographic coordinates.',
    'parameters': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'location': <String, dynamic>{
          'description': 'The center point to search around',
          'type': 'object',
          'properties': <String, dynamic>{
            'latitude': <String, dynamic>{'type': 'number'},
            'longitude': <String, dynamic>{'type': 'number'},
          },
          'required': <String>['latitude', 'longitude'],
        },
        'radiusKm': <String, dynamic>{
          'description': 'Search radius in kilometers',
          'type': 'number',
        },
        'category': <String, dynamic>{
          'description': 'Category filter, e.g. restaurant, park',
          'nullable': true,
          'type': 'string',
        },
      },

      'required': <String>['location', 'radiusKm'],
    },
  },
};

const sendEmailToolSchema = <String, dynamic>{
  'type': 'function',
  'function': <String, dynamic>{
    'name': 'sendEmail',
    'description': 'Composes and sends an email message.',
    'parameters': <String, dynamic>{
      'type': 'object',
      'properties': <String, dynamic>{
        'to': <String, dynamic>{
          'description': 'Recipient email address',
          'type': 'string',
        },
        'subject': <String, dynamic>{
          'description': 'Email subject line',
          'type': 'string',
        },
        'body': <String, dynamic>{
          'description': 'Email body content',
          'type': 'string',
        },
        'cc': <String, dynamic>{
          'description': 'CC recipients',
          'nullable': true,
          'type': 'array',
          'items': <String, dynamic>{'type': 'string'},
        },
      },

      'required': <String>['to', 'subject', 'body'],
    },
  },
};

const allToolSchemas = <Map<String, dynamic>>[
  getWeatherToolSchema,
  searchProductsToolSchema,
  findNearbyPlacesToolSchema,
  sendEmailToolSchema,
];

/// Maps tool names to handlers. Pass to your LLM agent loop.
final toolRegistry = ToolRegistry({
  'getWeather': (Map<String, dynamic> args) async {
    return getWeather(
      args['city'] as String,
      unit:
          _parseEnum(TemperatureUnit.values, args['unit'] as String) ??
          TemperatureUnit.celsius,
    );
  },
  'search_products': (Map<String, dynamic> args) async {
    return searchProducts(
      args['query'] as String,
      args['maxResults'] as int,
      includeOutOfStock: args['includeOutOfStock'] as bool?,
    );
  },
  'findNearbyPlaces': (Map<String, dynamic> args) async {
    return findNearbyPlaces(
      _parseGeoLocation(args['location'] as Map<String, dynamic>),
      (args['radiusKm'] as num).toDouble(),
      category: args['category'] as String?,
    );
  },
  'sendEmail': (Map<String, dynamic> args) async {
    return sendEmail(
      args['to'] as String,
      args['subject'] as String,
      args['body'] as String,
      cc: (args['cc'] as List?)?.cast<String>(),
    );
  },
});

// ignore: unused_element
T _parseEnum<T extends Enum>(List<T> values, String? raw) =>
    values.firstWhere((e) => e.name == raw, orElse: () => values.first);

// ignore: unused_element
GeoLocation _parseGeoLocation(Map<String, dynamic> m) => GeoLocation(
  latitude: (m['latitude'] as num).toDouble(),
  longitude: (m['longitude'] as num).toDouble(),
);
