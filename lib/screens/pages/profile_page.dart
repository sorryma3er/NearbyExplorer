import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;

  File? _pickedFile;
  int? _selectedDefaultIndex;
  bool _dirty = false;
  bool _uploading = false;

  late final AnimationController _anim;

  static const List<String> _defaultAvatarsUrls = [
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault1.png?alt=media&token=92a30175-1f49-4622-bebc-f001a7f4235b',
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault2.png?alt=media&token=c5cbb0aa-6fd0-4970-bb23-c5a5d2706ba9',
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault3.png?alt=media&token=751a96ad-3133-4a0d-8c3c-32e0d4017b80',
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault4.png?alt=media&token=ac7ae0a8-7a13-49d7-a89d-1234495b126c',
  ];

  TextStyle _commentTextStyle() => const TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w600,
  );

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 1024,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _pickedFile = File(x.path);
      _selectedDefaultIndex = null;
      _dirty = true;
    });
  }

  void _chooseDefault(int idx) {
    setState(() {
      _selectedDefaultIndex = idx;
      _pickedFile = null;
      _dirty = true;
    });
  }

  Future<void> _saveAvatar() async {
    if (!_dirty) return;
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _uploading = true);

    try {
      String? newUrl;

      if (_pickedFile != null) {
        final ref = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
        final task = await ref.putFile(
          _pickedFile!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        newUrl = await task.ref.getDownloadURL();
      } else if (_selectedDefaultIndex != null) {
        newUrl = _defaultAvatarsUrls[_selectedDefaultIndex!];
      }

      if (newUrl != null) {
        await user.updatePhotoURL(newUrl);
        await user.reload();
      }

      if (!mounted) return;
      setState(() {
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Container(
        decoration: _gradientDecoration,
        child: Center(
          child: Text('Not signed in', style: _commentTextStyle()),
        ),
      );
    }

    final displayName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (user.email ?? 'User');

    ImageProvider? avatarImage;
    if (_pickedFile != null) {
      avatarImage = FileImage(_pickedFile!);
    } else if (_selectedDefaultIndex != null) {
      avatarImage = NetworkImage(_defaultAvatarsUrls[_selectedDefaultIndex!]);
    } else if (user.photoURL != null) {
      avatarImage = NetworkImage(user.photoURL!);
    }

    final children = <Widget>[
      _buildAvatarSection(avatarImage, displayName)
          .animate(controller: _anim)
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slide(begin: const Offset(0, 0.15), curve: Curves.easeOut),

      const SizedBox(height: 32),

      _buildDefaultsHeader()
          .animate(controller: _anim)
          .fadeIn(delay: 150.ms, duration: 350.ms)
          .slide(begin: const Offset(0, 0.15)),

      const SizedBox(height: 12),

      _buildDefaultsScroller()
          .animate(controller: _anim)
          .fadeIn(delay: 250.ms, duration: 450.ms)
          .slide(begin: const Offset(0, 0.2)),

      const SizedBox(height: 40),

      _buildSaveButton()
          .animate(controller: _anim)
          .fadeIn(delay: 400.ms, duration: 400.ms)
          .slide(begin: const Offset(0, 0.15)),

      const SizedBox(height: 40),

      const Divider(),

      const SizedBox(height: 24),

      _buildLogoutTile()
          .animate(controller: _anim)
          .fadeIn(delay: 550.ms, duration: 400.ms)
          .slide(begin: const Offset(0, 0.1)),
    ];

    return Container(
      decoration: _gradientDecoration,
      child: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: children,
            ),
            if (_uploading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(strokeWidth: 5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _gradientDecoration => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [ Color(0xFFee9ca7), Color(0xFFffdDe1) ],
    ),
  );

  Widget _buildAvatarSection(ImageProvider? avatarImage, String displayName) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickFromGallery,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.amber.shade200,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
                    (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase(),
                    style: _commentTextStyle().copyWith(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  )
                      : null,
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: _commentTextStyle().copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap avatar to pick from gallery\nor choose a default below',
            textAlign: TextAlign.center,
            style: _commentTextStyle().copyWith(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultsHeader() {
    return Text(
      'Default Avatars',
      style: _commentTextStyle().copyWith(fontSize: 14),
    );
  }

  Widget _buildDefaultsScroller() {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _defaultAvatarsUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (ctx, i) {
          final selected = _selectedDefaultIndex == i;
          return GestureDetector(
            onTap: () => _chooseDefault(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.green.withValues(alpha: 0.4) : Colors.grey,
                  width: selected ? 3 : 1.5,
                ),
                image: DecorationImage(
                  image: NetworkImage(_defaultAvatarsUrls[i]),
                  fit: BoxFit.cover,
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaveButton() {
    return FilledButton.icon(
      onPressed: !_dirty || _uploading ? null : _saveAvatar,
      icon: Icon(_dirty ? Icons.save : Icons.check),
      label: Text(
        _uploading
            ? 'Saving...'
            : _dirty
            ? 'Save Avatar'
            : 'Up to date',
        style: _commentTextStyle(),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  Widget _buildLogoutTile() {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.red.withValues(alpha: 0.2),
      leading: const Icon(Icons.logout, color: Colors.red),
      title: Text(
        'Log Out',
        style: _commentTextStyle().copyWith(color: Colors.red, fontSize: 16),
      ),
      onTap: _logout,
    );
  }
}