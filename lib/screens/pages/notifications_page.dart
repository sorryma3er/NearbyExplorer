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

  TextStyle _commentTextStyle() => const TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to view notifications.'));
    }

    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
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
          return Center(child: Text('No notifications', style: _commentTextStyle()));
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
            final read = data['read'] == true;

            return ListTile(
              tileColor: read ? null : Colors.amber.withValues(alpha: 0.3),
              leading: CircleAvatar(
                backgroundImage: (data['fromPhotoUrl'] as String?) != null
                    ? NetworkImage(data['fromPhotoUrl'] as String)
                    : null,
                child: (data['fromPhotoUrl'] == null)
                    ? Text(fromName.characters.first.toUpperCase())
                    : null,
              ),
              title: Text('$fromName replied to your comment', style: _commentTextStyle(),),
              subtitle: Text(
                'Tap to view it', style: _commentTextStyle(),
              ),
              trailing: read ? null : const Icon(Icons.fiber_new, color: Colors.redAccent, size: 18),
              onTap: () async {
                final notifRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .doc(doc.id);

                // mark as read
                notifRef.update({'read': true}).catchError((e){
                  debugPrint('Mark read failed: $e');
                });

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