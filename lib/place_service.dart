import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nearby_explorer/place_detail_model.dart';
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
        'X-Goog-FieldMask': 'places.name,places.displayName,places.formattedAddress,places.location,places.rating,places.photos',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Nearby Search failed with status code: ${response.statusCode}, body: ${response.body}');
    }

    /// parse the response body to a map, 'places' is the key to a list of places maps
    final data = json.decode(response.body) as Map<String, dynamic>;

    /// placesJson is a list of maps, each map is a real place
    final placesJson = (data['places'] as List<dynamic>? ?? []); // gracefully prevent error

    /// convert each map to a Place model as defined in place_model.dart
    final places = placesJson
      .map((place) => Place.fromJson(place as Map<String, dynamic>))
      .toList(); // convert to list of places

    return places;
  }

  Future<List<Place>> searchText({
    required String query,
    // optional bias circle:
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    final uri = Uri.parse('https://places.googleapis.com/v1/places:searchText'); // new APIs endpoint

    // build the JSON body
    final body = <String, dynamic>{
      'textQuery': query,
    };
    if (latitude != null && longitude != null && radius != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': latitude,
            'longitude': longitude,
          },
          'radius': radius,
        }
      };
    }
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,

        // ask only for the fields that factory func Place.fromJson knows about:
        'X-Goog-FieldMask': 'places.name,places.displayName,places.formattedAddress,places.location,places.rating,places.photos',
      },
      body: json.encode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('Text Search failed [${resp.statusCode}]: ${resp.body}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final list = (data['places'] as List<dynamic>? ?? []);
    return list
        .map((js) => Place.fromJson(js as Map<String, dynamic>))
        .toList();
  }

  Future<PlaceDetail> fetchPlaceDetail(String resourceName) async {
    final url = Uri.parse('https://places.googleapis.com/v1/$resourceName');

    final headers = {
      'X-Goog-Api-Key': _apiKey,

      // Header field mask no space, o/w bug!
      'X-Goog-FieldMask': 'name,displayName,formattedAddress,location,rating,userRatingCount,photos,reviews',
      'Content-Type': 'application/json',
    };

    final resp = await http.get(url, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception('Detail failed: ${resp.statusCode} body=${resp.body}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    return PlaceDetail.fromJson(data);
  }
}