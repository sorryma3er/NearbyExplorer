import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _displayNameController = TextEditingController(); // store display name
  XFile? _avatar; // store avatar
  int _currentPage = 0;
  bool _showProfileError = false;

  @override
  void dispose() {
    _pageController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _avatar = file;
      }); // update the avatar
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool("completeOnboarding", true); // set flag

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("User is null");
      return;
    }

    // handle photo upload and get Url
    String? photoUrl;
    if (_avatar != null) {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars/${user.uid}.jpg');
      final uploadTask = await storageRef.putFile(File(_avatar!.path));
      photoUrl = await uploadTask.ref.getDownloadURL(); // get the Url from bucket
    }

    // update Firebase auth profile
    await user.updateDisplayName(_displayNameController.text.trim());
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }
    await user.reload(); // refresh the user object

    // TODO navigate to home screen
    debugPrint("Navigate to home screen");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _handlePageViewChanged,
              physics: _pageScrollPhysics(),
              children: [
                _buildProfilePage(),

                // TODO onboarding tutorial
                Center(child: Text("Tutorial"),)
              ],
            ),

            Positioned(
              bottom: 10, left: 24, right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // prev button
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: const Text("Prev"),
                    )
                  else
                    const SizedBox(width: 40,),

                  // smooth indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: 2,
                    effect: ExpandingDotsEffect(
                      activeDotColor: Colors.lightBlueAccent,
                      dotColor: Colors.grey,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),

                  // next / complete button
                  TextButton(
                    onPressed: () {
                      if (_currentPage == 0) {
                        if (!_profileInfoComplete) {
                         setState(() {
                           _showProfileError = true;
                         });
                         return; // short circuit this function
                        }
                      }

                      if (_currentPage == 1) {
                        completeOnboarding();
                      } else {
                        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      }
                    },
                    child: Text(_currentPage == 1 ? "Complete" : "Next"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePageViewChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Widget _buildProfilePage() {
    final showError = _showProfileError && (_profileInfoComplete == false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // avatar picker
          GestureDetector(
            onTap: pickAvatar,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: showError ? Colors.redAccent : Colors.grey,
                  width: 2,
                ),

                image: _avatar == null
                    ? null
                    : DecorationImage(
                  image: FileImage(File(_avatar!.path)),
                  fit: BoxFit.cover,
                ),

              ),
              child: _avatar == null
                ? const Center(child: Icon(Icons.add_a_photo, size: 32,)) : null
            ),
          ),

          const SizedBox(height: 24,),

          // display name field
          TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: 'Display Name',
              hintText: 'Enter your display name',
              errorText: showError ? "Display name cannot be empty" : null,
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: showError ? Colors.redAccent : Colors.grey,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );

  }

  ScrollPhysics _pageScrollPhysics() {
    if (_currentPage == 0 && !_profileInfoComplete) { // disable scroll when acc info not complete
      return const NeverScrollableScrollPhysics();
    } else {
      return const BouncingScrollPhysics();
    }
  }

  bool get _profileInfoComplete {
    return _displayNameController.text.trim().isNotEmpty && _avatar != null;
  }

}
