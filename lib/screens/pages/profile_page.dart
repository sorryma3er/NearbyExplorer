import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  bool _reloading = false;

  TextStyle _commentTextStyle() => const TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w600,
  );

  Future<void> _reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _reloading = true);
    try {
      await user.reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      // Navigate back to login, removing all previous routes
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          'Not signed in',
          style: _commentTextStyle(),
        ),
      );
    }

    final displayName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (user.email ?? 'User');

    final photoUrl = user.photoURL;
    final initial = displayName.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : 'U';

    return RefreshIndicator(
      onRefresh: _reloadUser,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        children: [
          // Header Section
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.amber.shade200,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Text(
                        initial,
                        style: _commentTextStyle().copyWith(
                          fontSize: 40,
                          color: Colors.white,
                        ),
                      )
                          : null,
                    ),
                    if (_reloading)
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.black26,
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: _commentTextStyle().copyWith(
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // (Optional) Email row (if you want to show it and it differs)
          if (user.email != null && user.email != displayName)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: Text(
                user.email!,
                style: _commentTextStyle().copyWith(fontSize: 14),
              ),
            ),

          // Divider
          const Divider(height: 48),

          // Logout row
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Colors.red.withOpacity(0.12),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              'Log Out',
              style: _commentTextStyle().copyWith(
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            onTap: _logout,
          ),

          const SizedBox(height: 24),

          // Small hint
          Center(
            child: Text(
              'Pull down to refresh profile',
              style: _commentTextStyle()
                  .copyWith(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}