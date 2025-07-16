import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  
  @override
  State<StatefulWidget> createState() {
    return _RegisterScreenState();
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  /// create controller as same as Login screen
  final emailController = TextEditingController();
  final pwdController = TextEditingController();

  Future<void> onPressedRegister() async{
    final email = emailController.text;
    final pwd = pwdController.text;
    debugPrint('Register pressed: email: $email, pwd: $pwd');

    try {
      FirebaseAuth _auth = FirebaseAuth.instance;
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pwd,
      );
      // on success
      if (!mounted) return;
      _showMessage(context, 'Account created for ${userCredential.user?.email}');

      // redirect to login page with email filled in
      Navigator.pop(context, email);

    } on FirebaseAuthException catch (e) {
      String errorMessage;

      if (e.code == 'email-already-in-use') {
        errorMessage = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is badly formatted.';
      } else {
        errorMessage = 'Register failed: ${e.message}';
      }
      if (!mounted) return;
      _showMessage(context, errorMessage);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
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
                .animate()
                .fadeIn(duration: 800.ms, curve: Curves.easeOut),
          ),

          Positioned(
            top: 90, right: 50,
            child: Hero(
              tag: 'dec2',
              child: SvgPicture.asset('assets/dec2.svg', width: 100),
            ),
          ),

          Positioned(
            bottom: 200, left: 20,
            child: Hero(
              tag: 'dec3',
              child: SvgPicture.asset('assets/dec3.svg', width: 120),
            ),
          ),

          Positioned(
            bottom: 100, right: 100,
            child: Hero(
              tag: 'dec1',
              child: Image.asset('assets/dec1.png', width: 140),
            ),
          ),

          Positioned(
            top: 100, left: 50,
            child: Image.asset('assets/star.png', width: 140),
          ).animate()
              .slide(begin: const Offset(-1, 0), end: Offset.zero, delay: 300.ms, duration: 300.ms)
              .fade(delay: 600.ms, duration: 600.ms),

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
                  // Register word
                  Text('Register', style: Theme.of(context).textTheme.titleLarge)
                      .animate()
                      .fadeIn(delay: 900.ms, duration: 400.ms)
                      .slide(begin: const Offset(0, -0.3), end: Offset.zero, delay: 900.ms),

                  const SizedBox(height: 16),

                  // Email
                  TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email),
                      ),
                  )
                      .animate()
                      .fadeIn(delay: 1100.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // Password
                  TextField(
                      controller: pwdController,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: Icon(Icons.lock),
                      ),
                  )
                      .animate()
                      .fadeIn(delay: 1300.ms, duration: 400.ms),

                  const SizedBox(height: 20),

                  // Register button
                  ElevatedButton(
                    onPressed: onPressedRegister,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text('Register'),
                  )
                      .animate()
                      .fadeIn(delay: 1500.ms, duration: 400.ms),

                  const SizedBox(height: 12),

                  // back to login
                  TextButton(
                    onPressed: () => {
                      Navigator.pop(context)
                    },
                    child: const Text('Already have an account?'),
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

