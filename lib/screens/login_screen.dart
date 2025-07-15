import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: pwdController,
              obscureText: true, /// make it not visible
              decoration: InputDecoration(
                labelText: 'PassWord',
                hintText: 'Enter your password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16,),

            ElevatedButton(
              onPressed: _onPressedLogin,
              child: const Text('Login'),
            ),
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: () async {
                final focusNode = FocusScope.of(context);

                final newEmail = await Navigator.pushNamed(context, '/register');

                // if result is not null, prefill the email for user
                if (newEmail != null && newEmail is String) {
                  emailController.text = newEmail;
                  pwdController.text = ''; // refresh the pwd field

                  // move the focus to password field
                  focusNode.nextFocus();
                }
              },
              child: const Text('Don\'t have an account? Register now'),
            ),
          ],
        ),
      ),
    );
  }
}