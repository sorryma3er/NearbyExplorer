import 'package:flutter/material.dart';
import '../../place_service.dart';
import '../../place_detail_model.dart';
import '../../place_model.dart';

class PlaceDetailSheet extends StatefulWidget {
  final Place place;
  final PlaceService placeService;
  final String apiKey;

  const PlaceDetailSheet({
    super.key,
    required this.place,
    required this.placeService,
    required this.apiKey,
  });

  @override
  State<StatefulWidget> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<PlaceDetailSheet> {
  PlaceDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _favorited = false;
  bool _posting = false;
  bool _anonymous = false;

  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _checkFavorite();
  }

  Future<void> _load() async {
    try {
      final d = await widget.placeService.fetchPlaceDetail(widget.place.resourceName);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _checkFavorite() async {
    // TODO Firestore check if place is favorited
    setState(() => _favorited = false);
  }

  Future<void> _toggleFavorite() async {
    final newVal = !_favorited;
    setState(() => _favorited = newVal);

    try {
      // TODO write / delete favorite to Firestore
    } catch (e) {
      setState(() => _favorited = !newVal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _postComment() async {
    final txt = _commentController.text.trim();

    if (txt.isEmpty) return;
    setState(() => _posting = true);
    try {
      // TODO Firestore add comment
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: $e')),
      );
    } finally {
      setState(() => _posting = false);
    }
  }

  String formPhotoUrl(String photoName, {int w = 640}) => 'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=$w&key=${widget.apiKey}';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 1.0,

      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black26)],
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Text('Error: $_error'))
                : _buildContent(scrollController),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final d = _detail!;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: _header(d)),
        if (d.photos.isNotEmpty) SliverToBoxAdapter(child: _photoGallery(d)),
        SliverToBoxAdapter(child: _ratingAndReviews(d)),
        SliverToBoxAdapter(child: _appCommentsSection()),
        SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 32)),
      ],
    );
  }

  Widget _header(PlaceDetail d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  d.formattedAddress ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _favorited ? Icons.favorite : Icons.favorite_border,
              color: _favorited ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          )
        ],
      ),
    );
  }

  Widget _photoGallery(PlaceDetail d) {
    final photos = d.photos;
    return SizedBox(
      height: 140,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final photo = photos[i];

          return GestureDetector(
            onTap: () {
              // push full screen image viewer
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                formPhotoUrl(photo['name'], w: 400),
                width: 200,
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ratingAndReviews(PlaceDetail d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // rating badge
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(d.rating?.toStringAsFixed(1) ?? '-',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  )
                ),
                Text('${d.userRatingCount ?? 0} reviews',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),

          SizedBox(width: 12,),

          // review fetch from google map
          Expanded(
            child: d.reviews.isEmpty
                ? Text('No Google reviews loaded.',
                style: Theme.of(context).textTheme.bodySmall)
                : SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.vertical,
                      itemCount: d.reviews.length.clamp(0, 3),
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (_, i) {
                        final r = d.reviews[i];
                        return RichText(
                          text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall,
                          children: [
                            TextSpan(
                              text: '${r.authorName ?? 'User'} • ${r.rating?.toStringAsFixed(1) ?? ''}\n',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold
                              )
                            ),
                            TextSpan(text: r.text ?? ''),
                          ],
                          ),
                        );
                      },
                    ),
                ),
          )
        ],
      ),
    );
  }


}