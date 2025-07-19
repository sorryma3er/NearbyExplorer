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

  //tutorial hero
  static const heroExplore = 'tab_explore';
  static const heroFavorites = 'tab_favorites';
  static const heroNotifications = 'tab_notifications';
  static const heroProfile = 'tab_profile';

  TextStyle _commentTextStyle() => const TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w600,
  );

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

  static const List<String> _defaultAvatarsUrls = [
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault1.png?alt=media&token=92a30175-1f49-4622-bebc-f001a7f4235b',
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault2.png?alt=media&token=c5cbb0aa-6fd0-4970-bb23-c5a5d2706ba9',
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault3.png?alt=media&token=751a96ad-3133-4a0d-8c3c-32e0d4017b80',
    'https://firebasestorage.googleapis.com/v0/b/nearbyexplorer-942ea.firebasestorage.app/o/default_avatars%2Fdefault4.png?alt=media&token=ac7ae0a8-7a13-49d7-a89d-1234495b126c',
  ];

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
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
    } else if (_selectedDefIndex != null) {
      photoUrl = _defaultAvatarsUrls[_selectedDefIndex!];
    }

    // update Firebase auth profile
    await user.updateDisplayName(_displayNameController.text.trim());
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }
    await user.reload(); // refresh the user object

    await prefs.setBool('completeOnboarding_${user.uid}', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  static Widget _flightBuilder(BuildContext context,
      Animation<double> animation,
      HeroFlightDirection direction,
      BuildContext fromCtx,
      BuildContext toCtx) {
    final child = (direction == HeroFlightDirection.push
        ? toCtx.widget
        : fromCtx.widget);
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: .85, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        ),
        child: child,
      ),
    );
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
                  _buildRowShowcasePage(),
                  // _buildColumnDetailPage(),
                  // _buildFlyOutPage(),
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
                      count: 4,
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

                        if (_currentPage < 3) {
                          _pageController.nextPage(duration: 300.ms, curve: Curves.easeInOut);
                        } else {
                          completeOnboarding();
                        }
                      },
                      child: Text(_currentPage == 3 ? "Complete" : "Next"),
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

  Widget _buildRowShowcasePage() {
    final items = [
      (heroExplore, Icons.explore, 'Explore'),
      (heroFavorites, Icons.favorite, 'Favorites'),
      (heroNotifications, Icons.notifications, 'Notify'),
      (heroProfile, Icons.person, 'Profile'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title anim
          Text(
            'Your Tabs',
            style: _commentTextStyle().copyWith(
              fontSize: 28,
              color: Colors.purple,
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .slide(begin: const Offset(0, -0.15), curve: Curves.easeOut),

          const SizedBox(height: 12),

          // Subtitle anim
          Text(
            'A quick glance at the core areas',
            textAlign: TextAlign.center,
            style: _commentTextStyle().copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.purpleAccent,
            ),
          )
              .animate()
              .fadeIn(delay: 120.ms, duration: 350.ms)
              .slide(begin: const Offset(0, -0.12), curve: Curves.easeOut),

          const SizedBox(height: 36),

          // Icons row (each animates internally)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < items.length; i++)
                _SmallHeroIcon(
                  tag: items[i].$1,
                  icon: items[i].$2,
                  label: items[i].$3,
                  index: i,
                ),
            ],
          )
              .animate()
              .fadeIn(delay: 160.ms, duration: 300.ms), // slight fade for the whole row shell

          const Spacer(),

          // Hint text anim
          Text(
            'Next: see details',
            style: _commentTextStyle().copyWith(
              fontSize: 12,
              color: Colors.orangeAccent,
            ),
          )
              .animate()
              .fadeIn(delay: 500.ms, duration: 400.ms),

          const SizedBox(height: 90),
        ],
      ),
    );
  }

}

class _SmallHeroIcon extends StatelessWidget {
  final String tag;
  final IconData icon;
  final String label;
  final int index; // for stagger

  const _SmallHeroIcon({
    required this.tag,
    required this.icon,
    required this.label,
    required this.index,
  });

  TextStyle get _labelStyle => const TextStyle(
    fontFamily: 'SourGummy',
    fontWeight: FontWeight.w600,
    fontSize: 11,
    color: Colors.white70,
  );

  @override
  Widget build(BuildContext context) {
    final baseDelay = 120.ms * index;
    return Hero(
      tag: tag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: _labelStyle),
        ],
      ),
    ).animate(delay: baseDelay)
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slide(begin: const Offset(0, .25), curve: Curves.easeOut)
        .scale(begin: const Offset(.85, .85), end: const Offset(1, 1), duration: 420.ms);
  }
}