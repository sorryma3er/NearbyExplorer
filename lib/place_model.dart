class Place {
  final String id;
  final String name;
  final double lat, lng;
  final double rating;
  final List<String> photoReferences;

  //constructor
  Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.rating,
    this.photoReferences = const [],
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['placeId'] as String,
      name: json['displayName'] as String,
      lat: (json['geometry']['location']['latitude']as num).toDouble(),
      lng: (json['geometry']['location']['longitude']as num).toDouble(),
      rating: (json['rating'] as num? ?? 0).toDouble(), // if no rating set to be 0
      photoReferences: (json['photos'] as List<dynamic>? ?? [])
        .map((photo) => photo['photoReference'] as String)
        .toList(),
    );
  }
}
