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
      backgroundColor: Colors.white,
      body: Center(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          children: [
            const SizedBox(height: 36),

            // ARISE  icon
            Center(
              child: Image.asset(
                "assets/icons/icon.png", 
                width: 100, 
                height: 100
              )
            ),
            
            // ARISE logo
            Center(
              child: Image.asset(
                "assets/logo.png", 
                width: 225, 
                height: 60,
                fit: BoxFit.contain
              )
            ),

            const SizedBox(height: 16),

            // ARISE login text
            Center(
              child: Text(
                "Login", 
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF3C6E87),
                  fontFamily: 'Geist'
                )
              )
            ),

            const SizedBox(height: 32),

            // email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: "Email Address",
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Geist'
                ),
                filled: true,
                fillColor: Color(0xFFD3D3D3),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // password
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                hintText: "Password",
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Geist'
                ),
                filled: true,
                fillColor: Color(0xFFD3D3D3),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none,
                ),
              )
            ),

            const SizedBox(height: 16),

            // button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3C6E87),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: login,
              child: const Text(
                "Login",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontFamily: 'Geist'
                )
              ),
            ),

            const SizedBox(height: 24),

            // go to register page to sign up
            GestureDetector(
              onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                child: const Center(child: Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF3C6E87),
                    fontFamily: 'Geist'
                  )
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}