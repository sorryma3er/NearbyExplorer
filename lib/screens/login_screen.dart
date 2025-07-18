import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nearby_explorer/screens/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin, RouteAware{
  /// use TextEditingController to give the text field a controller, so that:
  /// enable immediate read & write to it
  /// auto fill after register
  /// have listener that can change widget state when text changes, meaning if the format wrong, maybe surrounding can show red to user
  final emailController = TextEditingController();
  final pwdController = TextEditingController();
  late final AnimationController _animController;
  final emailFocus = FocusNode();
  final pwdFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000)
    )..forward(); // start initial animation
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // called when coming back to this screen → replay animation
    _animController
      ..reset()
      ..forward();
  }

  Future<void> _onPressedLogin() async{
    final email = emailController.text;
    final pwd = pwdController.text;
    final pref = await SharedPreferences.getInstance();
    final bool seen = pref.getBool('completeOnboarding') ?? false;
    debugPrint('Login pressed: email: $email, pwd: $pwd');

    try {
      FirebaseAuth _auth = FirebaseAuth.instance;
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pwd,
      );
      // on success
      if (!mounted) return;
      _showMessage(context, 'Welcome back! ${userCredential.user?.email}');

      // navigate to onboarding screen if not seen onboarding
      if (seen) {
        //TODO navigate to home
        debugPrint("Navigate to home screen");
      } else {
        debugPrint("Navigate to onboarding screen");
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided for that user.';
      } else {
        errorMessage = 'Login failed: ${e.message}';
      }
      if (!mounted) return;
      _showMessage(context, errorMessage);
    }
  }

  /// helper func to show error message when login failed
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() { /// comes in pair with Controller, dispose it to avoid memory leak
    routeObserver.unsubscribe(this);
    _animController.dispose();
    emailController.dispose();
    pwdController.dispose();
    emailFocus.dispose();
    pwdFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill( // bg pic
            child: Image.asset('assets/bg3.jpg', fit: BoxFit.cover)
                .animate(controller: _animController)
                .fadeIn(duration: 800.ms, curve: Curves.easeOut),
          ),

          Positioned(
            top: 120, left: 30,
            child: Hero(tag: 'dec2', child: SvgPicture.asset('assets/dec2.svg', width: 110)),
          ).animate(controller: _animController)
          .slide(begin: const Offset(-1.0, -1.0), end: Offset.zero, delay: 300.ms)
          .fade(delay: 300.ms, duration: 500.ms),

          Positioned(
            top: 110, right: 30,
            child: Hero(tag: 'dec3', child: SvgPicture.asset('assets/dec3.svg', width: 150)),
          ).animate(controller: _animController)
          .slide(begin: const Offset(0.5, 0), end: Offset.zero, delay: 500.ms)
          .fade(delay: 500.ms, duration: 500.ms),

          Positioned(
            bottom: 130, right: 40,
            child: Hero(tag: 'dec1', child: Image.asset('assets/dec1.png', width: 165)),
          ).animate(controller: _animController)
          .scaleXY(begin: 0.8, end: 1.0, delay: 700.ms, duration: 600.ms)
          .fadeIn(delay: 700.ms, duration: 500.ms),

          // login form
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Login word
                  Text('Login', style: Theme.of(context).textTheme.titleLarge)
                      .animate(controller: _animController)
                      .fadeIn(delay: 900.ms, duration: 400.ms)
                      .slide(begin: const Offset(0, -0.3), end: Offset.zero, delay: 900.ms),

                  const SizedBox(height: 16),

                  // Email
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    focusNode: emailFocus,
                  )
                      .animate(controller: _animController)
                      .fadeIn(delay: 1100.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: pwdController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    focusNode: pwdFocus,
                  )
                      .animate(controller: _animController)
                      .fadeIn(delay: 1300.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Login button
                  ElevatedButton(
                    onPressed: _onPressedLogin,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Login'),
                  )
                      .animate(controller: _animController)
                      .fadeIn(delay: 1500.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // go to register screen
                  TextButton(
                    onPressed: () async {
                      final focus = FocusScope.of(context);
                      final newEmail = await Navigator.of(context).push<String>(
                        PageRouteBuilder(
                          pageBuilder: (_, anim, __) => const RegisterScreen(),
                          transitionDuration: const Duration(milliseconds: 1000),
                          reverseTransitionDuration: const Duration(milliseconds: 800),
                        ),
                      );

                      // prefill when its not null
                      if (newEmail != null && newEmail.isNotEmpty) {
                        emailController.text = newEmail;
                        pwdController.clear();
                        // move focus to password field for convenience
                        focus.requestFocus(pwdFocus);
                      }
                    },
                    child: const Text("Don't have an account? Register"),
                  )
                      .animate(controller: _animController)
                      .fadeIn(delay: 1700.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}