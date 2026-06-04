// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tools.dart';

// **************************************************************************
// ToolSchemaGenerator
// **************************************************************************

const getWeatherOpenAiToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'getWeather',
    'description':
        'Gets the current weather for a given city.\n\nReturns temperature, humidity, and wind conditions\nfor the requested location.',
    'parameters': <String, Object?>{
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
    },
  },
};

const getWeatherAnthropicToolSchema = <String, Object?>{
  'name': 'getWeather',
  'description':
      'Gets the current weather for a given city.\n\nReturns temperature, humidity, and wind conditions\nfor the requested location.',
  'input_schema': <String, Object?>{
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
  },
};

const getWeatherGeminiToolSchema = <String, Object?>{
  'name': 'getWeather',
  'description':
      'Gets the current weather for a given city.\n\nReturns temperature, humidity, and wind conditions\nfor the requested location.',
  'parameters': <String, Object?>{
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
  },
};

const getWeatherToolSchema = getWeatherOpenAiToolSchema;

const searchProductsOpenAiToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'search_products',
    'description': 'Searches for products matching a query string.',
    'parameters': <String, Object?>{
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
        'includeOutOfStock': <String, Object?>{
          'nullable': true,
          'type': 'boolean',
        },
      },

      'required': <String>['query', 'maxResults'],
    },
  },
};

const searchProductsAnthropicToolSchema = <String, Object?>{
  'name': 'search_products',
  'description': 'Searches for products matching a query string.',
  'input_schema': <String, Object?>{
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
      'includeOutOfStock': <String, Object?>{
        'nullable': true,
        'type': 'boolean',
      },
    },

    'required': <String>['query', 'maxResults'],
  },
};

const searchProductsGeminiToolSchema = <String, Object?>{
  'name': 'search_products',
  'description': 'Searches for products matching a query string.',
  'parameters': <String, Object?>{
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
      'includeOutOfStock': <String, Object?>{
        'nullable': true,
        'type': 'boolean',
      },
    },

    'required': <String>['query', 'maxResults'],
  },
};

const searchProductsToolSchema = searchProductsOpenAiToolSchema;

const findNearbyPlacesOpenAiToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'findNearbyPlaces',
    'description':
        'Finds nearby places of interest based on geographic coordinates.',
    'parameters': <String, Object?>{
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
    },
  },
};

const findNearbyPlacesAnthropicToolSchema = <String, Object?>{
  'name': 'findNearbyPlaces',
  'description':
      'Finds nearby places of interest based on geographic coordinates.',
  'input_schema': <String, Object?>{
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
  },
};

const findNearbyPlacesGeminiToolSchema = <String, Object?>{
  'name': 'findNearbyPlaces',
  'description':
      'Finds nearby places of interest based on geographic coordinates.',
  'parameters': <String, Object?>{
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
  },
};

const findNearbyPlacesToolSchema = findNearbyPlacesOpenAiToolSchema;

const sendEmailOpenAiToolSchema = <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': 'sendEmail',
    'description': 'Composes and sends an email message.',
    'parameters': <String, Object?>{
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
          'description': 'CC recipients',
          'nullable': true,
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
      },

      'required': <String>['to', 'subject', 'body'],
    },
  },
};

const sendEmailAnthropicToolSchema = <String, Object?>{
  'name': 'sendEmail',
  'description': 'Composes and sends an email message.',
  'input_schema': <String, Object?>{
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
        'description': 'CC recipients',
        'nullable': true,
        'type': 'array',
        'items': <String, Object?>{'type': 'string'},
      },
    },

    'required': <String>['to', 'subject', 'body'],
  },
};

const sendEmailGeminiToolSchema = <String, Object?>{
  'name': 'sendEmail',
  'description': 'Composes and sends an email message.',
  'parameters': <String, Object?>{
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
        'description': 'CC recipients',
        'nullable': true,
        'type': 'array',
        'items': <String, Object?>{'type': 'string'},
      },
    },

    'required': <String>['to', 'subject', 'body'],
  },
};

const sendEmailToolSchema = sendEmailOpenAiToolSchema;

const allToolSchemas = <JsonObject>[
  getWeatherOpenAiToolSchema,
  searchProductsOpenAiToolSchema,
  findNearbyPlacesOpenAiToolSchema,
  sendEmailOpenAiToolSchema,
];

/// Generated registry - provides named schema getters and tool dispatch.
final class _ToolRegistry extends ToolRegistry {
  const _ToolRegistry(super.handlers, super.schemas);

  /// OpenAI-compatible schema for [getWeather].
  JsonObject get getWeather => schemaFor('getWeather');

  /// OpenAI-compatible schema for [searchProducts].
  JsonObject get searchProducts => schemaFor('search_products');

  /// OpenAI-compatible schema for [findNearbyPlaces].
  JsonObject get findNearbyPlaces => schemaFor('findNearbyPlaces');

  /// OpenAI-compatible schema for [sendEmail].
  JsonObject get sendEmail => schemaFor('sendEmail');
}

/// The generated tool registry for this file.
/// Use [toolRegistry.schemasFor] to select provider schemas,
/// and [toolRegistry.call] to dispatch model tool calls.
final toolRegistry = _ToolRegistry(
  {
    'getWeather': (JsonObject args) async {
      return getWeather(
        ToolRegistry.getRequiredArg<String>(args, 'city'),
        unit:
            _parseEnum(
              TemperatureUnit.values,
              ToolRegistry.getOptionalArg<String>(args, 'unit'),
              'unit',
            ) ??
            TemperatureUnit.celsius,
      );
    },
    'search_products': (JsonObject args) async {
      return searchProducts(
        ToolRegistry.getRequiredArg<String>(args, 'query'),
        ToolRegistry.getRequiredArg<int>(args, 'maxResults'),
        includeOutOfStock: ToolRegistry.getOptionalArg<bool>(
          args,
          'includeOutOfStock',
        ),
      );
    },
    'findNearbyPlaces': (JsonObject args) async {
      return findNearbyPlaces(
        _parseGeoLocation(ToolRegistry.getRequiredObjectArg(args, 'location')),
        ToolRegistry.getRequiredDoubleArg(args, 'radiusKm'),
        category: ToolRegistry.getOptionalArg<String>(args, 'category'),
      );
    },
    'sendEmail': (JsonObject args) async {
      return sendEmail(
        ToolRegistry.getRequiredArg<String>(args, 'to'),
        ToolRegistry.getRequiredArg<String>(args, 'subject'),
        ToolRegistry.getRequiredArg<String>(args, 'body'),
        cc: ToolRegistry.getOptionalListArg<String>(args, 'cc'),
      );
    },
  },
  {
    SchemaFlavor.openAi: <String, JsonObject>{
      'getWeather': getWeatherOpenAiToolSchema,
      'search_products': searchProductsOpenAiToolSchema,
      'findNearbyPlaces': findNearbyPlacesOpenAiToolSchema,
      'sendEmail': sendEmailOpenAiToolSchema,
    },
    SchemaFlavor.anthropic: <String, JsonObject>{
      'getWeather': getWeatherAnthropicToolSchema,
      'search_products': searchProductsAnthropicToolSchema,
      'findNearbyPlaces': findNearbyPlacesAnthropicToolSchema,
      'sendEmail': sendEmailAnthropicToolSchema,
    },
    SchemaFlavor.gemini: <String, JsonObject>{
      'getWeather': getWeatherGeminiToolSchema,
      'search_products': searchProductsGeminiToolSchema,
      'findNearbyPlaces': findNearbyPlacesGeminiToolSchema,
      'sendEmail': sendEmailGeminiToolSchema,
    },
  },
);

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
