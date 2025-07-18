import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../constraint.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  int? _selectedDefIndex; // index of default avatar list

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
        _selectedDefIndex = null;
      }); // update the avatar
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("completeOnboarding", true); // set flag
    debugPrint("Complete onboarding ${prefs.getBool("completeOnboarding")}");

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
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            colors: [
              kPurpleGray,
              kCambridge,
              kMintGreen,
              kSeaSalt,
              kApricot,
            ],
          ),
        ),
        child: SafeArea(
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
      ),
    );
  }

  void _handlePageViewChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  // default avatars
  final List<String> _defaultAvatars = [
    'assets/default1.png',
    'assets/default2.png',
    'assets/default3.png',
    'assets/default4.png',
  ];

  Widget _buildProfilePage() {
    final showError = _showProfileError && (_profileInfoComplete == false);

    //decide which picture to show in the big circle
    ImageProvider? bigImage;
    if (_avatar != null) {
      bigImage = FileImage(File(_avatar!.path));
    } else if (_selectedDefIndex != null) {
      bigImage = AssetImage(_defaultAvatars[_selectedDefIndex!]);
    }

    return Stack(
      children: [
        Positioned(
          bottom: 190, left: 25,
          child: SvgPicture.asset('assets/onboard_dec1.svg', width: 160),
        ).animate()
            .slide(begin: const Offset(-1, 0), end: Offset.zero, duration: 500.ms, delay: 300.ms)
            .fade(duration: 500.ms, delay: 300.ms, curve: Curves.easeInOut),

        Positioned(
          bottom: 80, right: 30,
          child: SvgPicture.asset('assets/onboard_dec2.svg', width: 180),
        ).animate()
            .slide(begin: const Offset(1, 0), end: Offset.zero, duration: 500.ms, delay: 300.ms)
            .fade(duration: 500.ms, delay: 300.ms, curve: Curves.easeInOut),

        Positioned(
          top: 30,
          left: 24,
          right: 24,
          child: _buildHeaderText(context),
        ).animate()
            .slide(begin: const Offset(0, -0.5), end: Offset.zero, delay: 100.ms)
            .fadeIn(duration: 300.ms, delay: 100.ms),

        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
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

                    image: bigImage == null
                        ? null
                        : DecorationImage(
                      image: bigImage,
                      fit: BoxFit.cover,
                    ),

                  ),
                  child: bigImage == null
                      ? const Center(child: Icon(Icons.add_a_photo, size: 32,)) : null,
                ),
              ).animate()
                  .fadeIn(delay: 500.ms, duration: 500.ms),

              const SizedBox(height: 24,),

              // row of default avatars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _defaultAvatars.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _avatar = null; // clear gallery pick
                            _selectedDefIndex = i; // mark this one selected
                            _showProfileError = false; // clear any error
                          });
                        },
                        child: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedDefIndex == i ? Colors.green : Colors.grey,
                              width: _selectedDefIndex == i ? 3 : 1.5,
                            ),
                            image: DecorationImage(
                              image: AssetImage(_defaultAvatars[i]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        // now animate each circle in:
                            .animate()
                            .fadeIn(delay: (i * 200).ms, duration: 500.ms)
                            .slide(begin: const Offset(-0.3, 0), end: Offset.zero, duration: 500.ms, delay: (i * 200).ms,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24,),

              // display name field
              TextField(
                controller: _displayNameController,
                onChanged: (_) => setState(() {}),
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
              ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
            ],
          ),
        ),
      ],
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
    bool hasName = _displayNameController.text.trim().isNotEmpty;
    bool hasAvatar = _avatar != null || _selectedDefIndex != null;
    return hasName && hasAvatar;
  }

  Widget _buildHeaderText(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // build a two‐color gradient shader that spans the full width
        final shader = LinearGradient(
          colors: [ Colors.purpleAccent, Colors.yellowAccent, Colors.purple],
        ).createShader(
          Rect.fromLTWH(0, 0, constraints.maxWidth, 0),
        );

        return Text(
          "Make your profile",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'SourGummy',
            fontSize: 34,
            fontWeight: FontWeight.w600,
            foreground: Paint()..shader = shader,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(2, 2),
              ),
            ],
          ),
        );
      },
    );
  }

}
