import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view favorites.'));
    }

    final favsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .orderBy('createdAt', descending: true);

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
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
            return const Center(child: Text('No favorites yet',
                style: TextStyle(fontFamily: 'SourGummy', fontWeight: FontWeight.w600)
            ));
          }

          return ListView.separated(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final placeId = data['placeId'] as String;
              final displayName = data['displayName'] as String? ?? '';
              final addr = data['formattedAddress'] as String? ?? '';
              final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
              final primaryPhotoName = data['primaryPhotoName'] as String?;

              Widget leading;
              if (primaryPhotoName == null) {
                leading = const Icon(Icons.place, size: 46);
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
                    const Icon(Icons.broken_image, size: 40),
                  ),
                );
              }

              return ListTile(
                leading: leading,
                title: Text(displayName),
                subtitle: Text(
                  '${rating.toStringAsFixed(1)} ★\n$addr',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  // Reconstruct a minimal Place model
                  final resourceName = 'places/$placeId';
                  final place = Place(
                    resourceName: resourceName,
                    displayName: displayName,
                    formattedAddress: addr,
                    lat: 0, // use 0 here since once go into place detail will fetch again
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
              );
            },
          );
        },
      ),
    );
  }
}