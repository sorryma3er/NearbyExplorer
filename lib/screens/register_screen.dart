import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      appBar: AppBar(
        title: const Text('Register'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
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
            const SizedBox(height: 16,),

            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16,),

            ElevatedButton(
              onPressed: onPressedRegister,
              child: const Text('Register'),
            ),
            const SizedBox(height: 12,),
            
            ElevatedButton(
              onPressed: () => {
                Navigator.pop(context),
              },
              child: const Text('Already have an account? Login now'),
            ),
          ],
        ),
      ),
    );
  }
}

