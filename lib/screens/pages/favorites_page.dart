import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../place_service.dart';
import '../../place_model.dart';
import './place_detail_page.dart';

class FavoritesPage extends StatelessWidget {
  final PlaceService placeService;
  final String apiKey;

  const FavoritesPage({
    super.key,
    required this.placeService,
    required this.apiKey,
  });

  String buildPhotoUrl(String photoName, String apiKey, {int max = 160}) =>
      'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=$max&maxHeightPx=$max&key=$apiKey';

  TextStyle get _titleStyle => const TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: Colors.black,
  );

  TextStyle get _subtitleStyle => TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.25,
    color: Colors.black.withValues(alpha: 0.75),
  );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _gradientWrapper(
        const Center(
          child: Text(
            'Please sign in to view favorites.',
            style: TextStyle(fontFamily: 'SourGummy', fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    final favsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .orderBy('createdAt', descending: true);

    return _gradientWrapper(
      StreamBuilder<QuerySnapshot>(
        stream: favsQuery.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No favorites yet',
                style: TextStyle(fontFamily: 'SourGummy', fontWeight: FontWeight.w600),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final placeId = data['placeId'] as String;
              final displayName = data['displayName'] as String? ?? '';
              final addr = data['formattedAddress'] as String? ?? '';
              final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
              final primaryPhotoName = data['primaryPhotoName'] as String?;

              Widget leading;
              if (primaryPhotoName == null) {
                leading = Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place, size: 40, color: Colors.white),
                );
              } else {
                final url = buildPhotoUrl(primaryPhotoName, apiKey);
                leading = ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 40, color: Colors.white70),
                  ),
                );
              }

              final card = Material(
                color: Colors.white.withValues(alpha: 0.55),
                elevation: 0,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    final resourceName = 'places/$placeId';
                    final place = Place(
                      resourceName: resourceName,
                      displayName: displayName,
                      formattedAddress: addr,
                      lat: 0,
                      lng: 0,
                      rating: rating,
                      photoNames: primaryPhotoName == null ? [] : [primaryPhotoName],
                    );
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => PlaceDetailSheet(
                        place: place,
                        placeService: placeService,
                        apiKey: apiKey,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: _titleStyle),
                              const SizedBox(height: 4),
                              Text(
                                '${rating.toStringAsFixed(1)} ★ • $addr',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _subtitleStyle,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              );

              // apply staggered animation
              return card
                  .animate(delay: Duration(milliseconds: 70 * i))
                  .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                  .slide(
                begin: const Offset(0, .15),
                end: Offset.zero,
                duration: 400.ms,
                curve: Curves.easeOut,
              )
                  .scale(
                begin: const Offset(.95, .95),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOut,
              );
            },
          );
        },
      ),
    );
  }

  Widget _gradientWrapper(Widget child) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFee9ca7),
          Color(0xFFffdDe1),
        ],
      ),
    ),
    child: SafeArea(child: child),
  );
}