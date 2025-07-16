import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> {
  /// use TextEditingController to give the text field a controller, so that:
  /// enable immediate read & write to it
  /// auto fill after register
  /// have listener that can change widget state when text changes, meaning if the format wrong, maybe surrounding can show red to user
  final emailController = TextEditingController();
  final pwdController = TextEditingController();

  Future<void> _onPressedLogin() async{
    final email = emailController.text;
    final pwd = pwdController.text;
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

      // navigate to onboarding screen
      Navigator.pushReplacementNamed(context, '/onboarding');
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
    emailController.dispose();
    pwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill( // bg pic
            child: Image.asset('assets/bg3.jpg', fit: BoxFit.cover)
                .animate().fadeIn(duration: 800.ms, curve: Curves.easeOut),
          ),

          Positioned(
            top: 100, left: 30,
            child: SvgPicture.asset('assets/dec2.svg', width: 140),
          ).animate(onPlay: (ctrl) => ctrl.forward())
          .slide(begin: const Offset(-1.0, -1.0), end: Offset.zero, delay: 300.ms)
          .fade(delay: 300.ms, duration: 600.ms),

          Positioned(
            top: 120, right: 30,
            child: SvgPicture.asset('assets/dec3.svg', width: 150),
          ).animate()
          .slide(begin: const Offset(0.5, 0), end: Offset.zero, delay: 500.ms)
          .fade(delay: 500.ms, duration: 500.ms),

          Positioned(
            bottom: 140, right: 60,
            child: Image.asset('assets/dec1.png', width: 165),
          ).animate()
          .scaleXY(begin: 0.8, end: 1.0, delay: 700.ms, duration: 600.ms)
          .fadeIn(delay: 700.ms, duration: 600.ms),

          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Login word
                  Text('Login', style: Theme.of(context).textTheme.displayMedium)
                      .animate()
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
                  ).animate().fadeIn(delay: 1100.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // Password
                  TextField(
                    controller: pwdController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ).animate().fadeIn(delay: 1300.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Login button
                  ElevatedButton(
                    onPressed: _onPressedLogin,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Login'),
                  )
                      .animate()
                      .fadeIn(delay: 1500.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // Register 链接
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Don\'t have an account? Register'),
                  )
                      .animate()
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