import 'package:flutter/material.dart';

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

  void onPressedRegister() {
    final email = emailController.text;
    final pwd = pwdController.text;
    //TODO: cooperate with firebase
    debugPrint('Register pressed: email: $email, pwd: $pwd');
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

