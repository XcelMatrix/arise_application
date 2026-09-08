import 'package:flutter/material.dart';
import 'package:arise_application/auth_servers/auth_service.dart';
import 'package:arise_application/pages/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // get auth service
  final authService = AuthService();

  // text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // login button pressed
  void login() async {
    // prepare data
    final email = _emailController.text;
    final password = _passwordController.text;

    // attempt login..
    try {
        await authService.signInWithEmailPassword(email, password); 
    } 

    // catch any errors
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // Build User Interface
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( 
        title: const Text("Login")
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 50),
        children: [
          //email
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: "Email"),
          ),

          //password
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: "Password")
          ),

          const SizedBox(height: 12),

          // button
          ElevatedButton(
            onPressed: login,
            child: const Text("Login"),
          ),

          const SizedBox(height: 12),

          // go to register page to sign up
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const RegisterPage()
              )),

              child: const Center(child: Text("Don't have an account? Sign Up")),
          ),
        ],
      ),
    );
  }
}