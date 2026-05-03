import 'package:tool_schema_generator/tool_schema_generator.dart';

part 'tools.g.dart';

// --------------------------------------------------------------------------
// Example enum — the generator will produce "enum": ["celsius", "fahrenheit"]
// --------------------------------------------------------------------------

/// Supported temperature units.
enum TemperatureUnit { celsius, fahrenheit, kelvin }

// --------------------------------------------------------------------------
// Example nested class — the generator will produce a nested object schema
// --------------------------------------------------------------------------

/// Geographic coordinates.
class GeoLocation {
  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  const GeoLocation({required this.latitude, required this.longitude});
}

// --------------------------------------------------------------------------
// Tool functions
// --------------------------------------------------------------------------

/// Gets the current weather for a given city.
///
/// Returns temperature, humidity, and wind conditions
/// for the requested location.
@Tool()
String getWeather(
  @Describe('The name of the city to look up') String city, {
  @Describe('The unit for temperature values')
  TemperatureUnit unit = TemperatureUnit.celsius,
}) {
  return '{"temp": 22, "unit": "$unit", "city": "$city"}';
}

/// Searches for products matching a query string.
@Tool(name: 'search_products')
List<Map<String, dynamic>> searchProducts(
  @Describe('The search query') String query,
  @Describe('Maximum number of results') int maxResults, {
  bool? includeOutOfStock,
}) {
  return [];
}

/// Finds nearby places of interest based on geographic coordinates.
@Tool()
Map<String, dynamic> findNearbyPlaces(
  @Describe('The center point to search around') GeoLocation location,
  @Describe('Search radius in kilometers') double radiusKm, {
  @Describe('Category filter, e.g. restaurant, park') String? category,
}) {
  return {};
}

/// Sends an email message to the specified recipients.
@Tool(description: 'Composes and sends an email message.')
void sendEmail(
  @Describe('Recipient email address') String to,
  @Describe('Email subject line') String subject,
  @Describe('Email body content') String body, {
  @Describe('CC recipients') List<String>? cc,
}) {}
