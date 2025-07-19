import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  // for reply comment
  String? _replyToCommentId;
  String? _replyToAuthorDisplay; // for UI hint

  @override
  void initState() {
    super.initState();
    _load();
    _checkFavorite();
  }

  //prevent mem leak
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

  String placeIdFromResource(String rn) => rn.split('/').last;

  Future<void> _checkFavorite() async {
    final user = _auth.currentUser;
    if (user == null) return; // user not logged in yet
    final placeId = placeIdFromResource(widget.place.resourceName);
    final doc = await _fs.collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(placeId)
        .get();
    if (!mounted) return;
    setState(() => _favorited = doc.exists);
  }

  Future<void> _toggleFavorite() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to favorite')),
      );
      return;
    }
    final place = widget.place;
    final placeId = placeIdFromResource(place.resourceName);
    final ref = _fs.collection('users').doc(user.uid)
        .collection('favorites').doc(placeId);

    final newVal = !_favorited;
    setState(() => _favorited = newVal);

    try {
      if (newVal) {
        await ref.set({
          'placeId': placeId,
          'resourceName': place.resourceName,
          'displayName': place.displayName,
          'formattedAddress': place.formattedAddress,
          'primaryPhotoName': place.photoNames.isEmpty ? null : place.photoNames.first,
          'rating': place.rating,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.delete();
      }
    } catch (e) {
      // revert
      if (mounted) {
        setState(() => _favorited = !newVal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Favorite failed: $e')),
        );
      }
    }
  }

  // helper func to get collection reference for comments
  CollectionReference<Map<String, dynamic>> _commentsCol(String placeId) =>
      _fs.collection('places').doc(placeId).collection('comments');

  Future<void> _postComment() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final placeId = placeIdFromResource(widget.place.resourceName);
    final isReply = _replyToCommentId != null;

    // enforce only 2 levels (top-level + one reply level), no 3rd layers reply
    if (_replyToCommentId != null) {
      final parentSnap = await _commentsCol(placeId).doc(_replyToCommentId!).get();
      final parentData = parentSnap.data();
      if (parentData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Original comment no longer exists.')),
        );
        setState(() {
          _replyToCommentId = null;
          _replyToAuthorDisplay = null;
        });
        return;
      }
      // if parent itself has a parentId, which means right now is the 3rd layer
      if (parentData['parentId'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nested replies beyond one level are disabled.')),
        );
        setState(() {
          _replyToCommentId = null;
          _replyToAuthorDisplay = null;
        });
        return; // block
      }
    }

    setState(() {
      _posting = true;
    });

    try {
      final newDoc = _commentsCol(placeId).doc();
      final now = FieldValue.serverTimestamp();

      final commentData = {
        'userId': user.uid,
        'userDisplayName': _anonymous ? '' : (user.displayName ?? ''),
        'userPhotoUrl': _anonymous ? null : user.photoURL,
        'text': text,
        'anonymous': _anonymous,
        'parentId': _replyToCommentId, // null for top-level
        'replyCount': 0, // for top-level; stays 0 on replies
        'createdAt': now,
        'updatedAt': now,
        'deleted': false, //soft delete
      };

      WriteBatch batch = _fs.batch();
      batch.set(newDoc, commentData);

      // if this is a reply we increment parent replyCount
      if (isReply) {
        final parentRef = _commentsCol(placeId).doc(_replyToCommentId);
        batch.update(parentRef, {
          'replyCount': FieldValue.increment(1),
          'updatedAt': now,
        });
      }
      await batch.commit(); // commit to write to it

      // clear composer
      _commentController.clear();
      setState(() {
        _replyToCommentId = null;
        _replyToAuthorDisplay = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // helper to formPhotoUrl as before
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

  Widget _appCommentsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15), // whole background of app own comment
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(),

            const SizedBox(height: 16),

            _commentInput(),

            const SizedBox(height: 12),

            Divider(
              height: 28,
              thickness: 1,
              color: Colors.amber.withValues(alpha: 0.4),
            ),

            _commentsStreamList(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _communityPill(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Anonymous', style: _commentTextStyle()),
            const SizedBox(width: 4),
            Switch(
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ],
    );
  }

  Widget _communityPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: Colors.amber.withValues(alpha: 0.25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: Colors.red.withValues(alpha: 0.8)),

          const SizedBox(width: 6),

          Text(
            'Community Comments',
            style: TextStyle(
              color: Colors.amber.shade700,
              fontFamily: 'SourGummy',
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _commentTextStyle() => const TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w600,
  );

  Widget _commentInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar placeholder
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.amber.shade200,
          // TODO use users avatar here
          child: const Icon(Icons.person, color: Colors.white),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            children: [
              if (_replyToCommentId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to ${_replyToAuthorDisplay?.isEmpty ?? true ? "user" : _replyToAuthorDisplay}',
                          style: _commentTextStyle().copyWith(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),

                      GestureDetector(
                        onTap: () => setState(() {
                          _replyToCommentId = null;
                          _replyToAuthorDisplay = null;
                        }),
                        child: const Icon(Icons.close, size: 16),
                      )
                    ],
                  ),
                ),

              TextField(
                controller: _commentController,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Give ur opinion...',
                  hintStyle: _commentTextStyle(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),

              const SizedBox(height: 6),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _posting || _commentController.text.trim().isEmpty
                      ? null
                      : _postComment,
                  child: _posting
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Post', style: _commentTextStyle()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commentsStreamList() { // use StreamBuilder to build the list of comments
    final placeId = placeIdFromResource(widget.place.resourceName);

    final query = _commentsCol(placeId) // query for comments
        .where('parentId', isNull: true)
        .orderBy('createdAt', descending: true)
        .limit(30);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Text('Error loading comments: ${snap.error}',
              style: _commentTextStyle());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Text('No comments yet', style: _commentTextStyle());
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            return _commentTile(placeId, doc);
          },
        );
      },
    );
  }

  Widget _commentTile(String placeId, QueryDocumentSnapshot<Map<String, dynamic>> doc, {bool isReply = false}) {
    final data = doc.data();
    final deleted = data['deleted'] == true;
    final replyCount = (data['replyCount'] as int?) ?? 0;

    // skip the deleted comments that have no children reply
    if (deleted && replyCount == 0) {
      return const SizedBox.shrink();
    }

    final text = (deleted ? '[deleted]' : (data['text'] as String? ?? ''));
    final userDisplay = (data['anonymous'] == true || (data['userDisplayName'] as String?)?.isEmpty == true)
        ? 'Anonymous'
        : data['userDisplayName'] as String;
    final userPhoto = data['anonymous'] == true ? null : data['userPhotoUrl'] as String?;
    final isMine = _auth.currentUser?.uid == data['userId'];

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.amber.shade300,
      backgroundImage: (userPhoto != null && !deleted) ? NetworkImage(userPhoto) : null,
      child: (userPhoto == null || deleted)
          ? Text( // use the first letter of the user display name as avatar
        userDisplay.isNotEmpty ? userDisplay[0].toUpperCase() : '?',
        style: _commentTextStyle().copyWith(color: Colors.white),
      )
          : null,
    );

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 40 : 0, top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!deleted)
                      Text(userDisplay, style: _commentTextStyle().copyWith(fontSize: 13)),
                    if (!deleted) const SizedBox(height: 4),
                    Text(
                      text,
                      style: _commentTextStyle().copyWith(
                        fontSize: 14,
                        fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                        color: deleted ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!deleted) // no actions on placeholder
                      Row(
                        children: [
                          if (!isReply)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _replyToCommentId = doc.id;
                                  _replyToAuthorDisplay = userDisplay == 'Anonymous' ? '' : userDisplay;
                                });
                              },
                              icon: const Icon(Icons.reply, size: 16),
                              label: Text('Reply',
                                  style: _commentTextStyle().copyWith(fontSize: 12)),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero, minimumSize: const Size(40, 28)),
                            ),
                          if (isMine)
                            TextButton.icon(
                              onPressed: () => _softDeleteComment(placeId, doc.id),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: Text('Delete',
                                  style: _commentTextStyle().copyWith(fontSize: 12)),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero, minimumSize: const Size(50, 28)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          // always show replies (if any) for parent, even if parent is deleted.
          if (replyCount > 0 && !isReply)
            _repliesSection(placeId, doc.id, replyCount),
        ],
      ),
    );
  }

  Widget _repliesSection(String placeId, String parentId, int replyCount) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _commentsCol(placeId)
            .where('parentId', isEqualTo: parentId) // need to build index
            .where('deleted', isEqualTo: false) // filter out replies that been deleted
            .orderBy('createdAt', descending: false)
            .limit(15)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(4.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Text('Replies not loaded',
                style: _commentTextStyle().copyWith(fontSize: 12));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: docs
                .map((d) => _commentTile(placeId, d, isReply: true))
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _softDeleteComment(String placeId, String commentId) async {
    final commentRef = _commentsCol(placeId).doc(commentId);

    try {
      await _fs.runTransaction((tx) async {
        final commentSnap = await tx.get(commentRef);
        if (!commentSnap.exists) return;

        final data = commentSnap.data()!;
        if (data['deleted'] == true) return; // already deleted, nothing to do

        final parentId = data['parentId'];
        DocumentSnapshot<Map<String, dynamic>>? parentSnap;

        if (parentId != null) {
          final parentRef = _commentsCol(placeId).doc(parentId);
          parentSnap = await tx.get(parentRef);
        }

        // now can write to it
        final now = FieldValue.serverTimestamp();
        tx.update(commentRef, {
          'deleted': true,
          'text': '',
          'updatedAt': now,
        });

        // if it was a reply, decrement parent.replyCount
        if (parentId != null && parentSnap != null && parentSnap.exists) {
          final parentData = parentSnap.data()!;
          final current = (parentData['replyCount'] as int?) ?? 0;
          if (current > 0) {
            tx.update(parentSnap.reference, {
              'replyCount': current - 1,
              'updatedAt': now,
            });
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}