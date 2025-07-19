import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import './place_detail_page.dart';
import '../../place_model.dart';
import '../../place_service.dart';

class NotificationsPage extends StatelessWidget {
  final PlaceService placeService;
  final String apiKey;

  const NotificationsPage({
    super.key,
    required this.placeService,
    required this.apiKey,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to view notifications.'));
    }

    final query = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(30);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No notifications'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();
            final type = data['type'] as String? ?? '';
            if (type != 'reply') {
              return const SizedBox.shrink();
            }
            final fromName = (data['fromDisplayName'] as String?)?.trim().isNotEmpty == true
                ? data['fromDisplayName'] as String
                : 'Someone';
            final placeName = data['placeDisplayName'] as String? ?? 'a place';
            final preview = (data['textPreview'] as String?)?.trim();
            final read = data['read'] == true;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            return ListTile(
              tileColor: read ? null : Colors.amber.withOpacity(0.1),
              leading: CircleAvatar(
                backgroundImage: (data['fromPhotoUrl'] as String?) != null
                    ? NetworkImage(data['fromPhotoUrl'] as String)
                    : null,
                child: (data['fromPhotoUrl'] == null)
                    ? Text(fromName.characters.first.toUpperCase())
                    : null,
              ),
              title: Text('$fromName replied to your comment'),
              subtitle: Text(
                preview == null || preview.isEmpty
                    ? '(anonymous reply)'
                    : preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: read ? null : const Icon(Icons.fiber_new, color: Colors.redAccent, size: 18),
              onTap: () async {
                FirebaseFirestore.instance
                    .collection('notifications')
                    .doc(doc.id)
                    .update({'read': true});

                // navigate to place detail page via showModalBottomSheet
                final placeId = data['placeId'] as String;
                final resourceName = 'places/$placeId'; // if this is how you build it
                final place = Place(
                  resourceName: resourceName,
                  displayName: placeName,
                  formattedAddress: '',
                  photoNames: const [],
                  rating: 0,
                  lat: 0,
                  lng: 0,
                );
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PlaceDetailSheet(
                    place: place,
                    placeService: placeService,
                    apiKey: apiKey,
                    // (Optionally pass initial comment id)
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}