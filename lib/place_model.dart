class Place {
  final String resourceName;
  final String displayName;
  final String formattedAddress;
  final double lat, lng;
  final double rating;
  final List<String> photoNames;

  //constructor
  Place({
    required this.resourceName,
    required this.displayName,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.rating,
    this.photoNames = const [],
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final resourceName = json['name'] as String? ?? '';
    final displayBlock = json['displayName'] as Map<String, dynamic>? ?? {};
    final displayName = displayBlock['text'] as String? ?? '';
    final formattedAddress = json['formattedAddress'] as String? ?? '';
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    final lat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
    final rating = (json['rating'] as num?)?.toDouble() ?? 0.0;
    final photosJson = json['photos'] as List<dynamic>? ?? [];
    final photoNames = photosJson
        .map((p) => (p as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .toList();

    return Place(
      resourceName: resourceName,
      displayName: displayName,
      formattedAddress: formattedAddress,
      lat: lat,
      lng: lng,
      rating: rating,
      photoNames: photoNames,
    );
  }
}
