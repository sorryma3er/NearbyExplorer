import 'dart:convert';
import 'package:http/http.dart' as http;
import './place_model.dart';

class PlaceService {
  final String _apiKey;
  PlaceService(this._apiKey);

  Future<List<Place>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    double radius = 1000, // in meters
    List<String> types = const ['restaurant'],
  }) async {
    final uri = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final body = {
      'includedTypes': types,
      'locationRestriction': {
        'circle': {
          'center': {
            'latitude': latitude,
            'longitude': longitude,
          },
          'radius': radius,
        }
      }
    };

    final response = await
    http.post( // form the HTTP request to the server in POST method
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,

        // include the fields that we want to receive in the response
        'X-Goog-FieldMask': 'places.displayName, places.formattedAddress, places.geometry, places.rating, places.photos',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Nearby Search failed with status code: ${response.statusCode}, body: ${response.body}');
    }

    /// parse the response body to a map, 'places' is the key to a list of places maps
    final data = json.decode(response.body) as Map<String, dynamic>;

    /// placesJson is a list of maps, each map is a real place
    final placesJson = (data['places'] as List<dynamic>);

    /// convert each map to a Place model as defined in place_model.dart
    final places = placesJson
      .map((place) => Place.fromJson(place as Map<String, dynamic>))
      .toList(); // convert to list of places

    return places;
  }
}