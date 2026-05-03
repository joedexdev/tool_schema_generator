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
