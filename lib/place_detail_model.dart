class PlaceDetail {
  final String resourceName;
  final String displayName;
  final String? formattedAddress;
  final double? rating;
  final int? userRatingCount;
  final List<dynamic> photos;
  final List<PlaceReview> reviews;

  PlaceDetail({
    required this.resourceName,
    required this.displayName,
    this.formattedAddress,
    this.rating,
    this.userRatingCount,
    this.photos = const [],
    this.reviews = const [],
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    List<dynamic> photos = (json['photos'] as List?) ?? [];
    List<PlaceReview> reviews = ((json['reviews'] as List?) ?? [])
        .map((r) => PlaceReview.fromJson(r))
        .toList();

    return PlaceDetail(
      resourceName: json['name'] as String,
      displayName: (json['displayName']?['text'] ?? '') as String,
      formattedAddress: json['formattedAddress'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: json['userRatingCount'] as int?,
      photos: photos,
      reviews: reviews,
    );
  }
}

class PlaceReview {
  final String? authorName;
  final double? rating;
  final String? text;

  PlaceReview({this.authorName, this.rating, this.text});

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    return PlaceReview(
      authorName: json['authorAttribution']?['displayName'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      text: json['text']?['text'] as String?,
    );
  }
}