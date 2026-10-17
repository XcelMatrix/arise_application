import 'package:flutter/material.dart';
import 'package:arise_application/auth_servers/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const RegisterPage());
  }

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // get auth service
  final authService = AuthService();

  // loading state
  bool _isLoading = false;

  // password visibility state
  bool _isPasswordVisible = false;

  // text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  //sign up button pressed
  void signUp() async {
    // prepare data
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // check that passwords match
    if (password != confirmPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      }
      return;
    }

    // set loading state
    setState(() {
      _isLoading = true;
    });

    // attempt sign up..
    try {
      await authService.signUpWithEmailPassword(email, password);

      if (!mounted) return;

      // pop this register page
      Navigator.pop(context);
    } 

    // catch any errors
    catch (error) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error ")));
      }
    }

    // finally reset loading state
    finally {
      // reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // dispose controllers
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          children : [
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

            // ARISE sign up text
            Center(
              child: Text(
                "Sign Up", 
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF3C6E87),
                  fontFamily: 'Geist'
                )
              )
            ),

            const SizedBox(height: 32),

            //email
            TextField(
              controller: _emailController,
              enabled: !_isLoading,
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

            //password
            TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
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

                // password visibility toggle
                suffixIcon: IconButton(
                  icon: Icon(
                    // toggle icon based on visibility state
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            //confirm password
            TextField(
              controller: _confirmPasswordController,
              enabled: !_isLoading,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: "Confirm Password",
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

                // password visibility toggle
                suffixIcon: IconButton(
                  icon: Icon(
                    // toggle icon based on visibility state
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
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
              onPressed: _isLoading ? null : signUp,
              child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: 'Geist'
                  )
                ),
            )
          ],
        )
      ),
    );
  }
}