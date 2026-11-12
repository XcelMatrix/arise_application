import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/auth/services/auth_service.dart';
import 'package:arise_application/features/auth/pages/role_select_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/help/pages/tour_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  // Route for navigation
  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const LoginPage());
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // get auth service
  final authService = AuthService();

  // text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // loading state
  bool _isLoading = false;

  // password visibility state
  bool _isPasswordVisible = false;

  // login button pressed
  void login() async {
    // set loading state
    setState(() {
      _isLoading = true;
    });

    // prepare data
    final email = _emailController.text;
    final password = _passwordController.text;

    // attempt login..
    try {
      await authService.signInWithEmailPassword(email, password);

      if (!mounted) return;

      // short first-run tour (or straight to Home if switched off)
      await TourPage.openAfterLogin(context);
    }

    // catch auth exception
    on AuthException catch (error) {
      if (mounted && (error.code == 'email_not_confirmed' ||
          error.message.toLowerCase().contains('not confirmed'))) {
        await _offerResend(email);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Auth Error: ${error.message} ")));
      }
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

  // "Email not confirmed": offer to send the verification email again
  Future<void> _offerResend(String email) async {
    final resend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify your email'),
        content: const Text(
            'Open the verification link we emailed you, then log in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('OK')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Resend email')),
        ],
      ),
    );
    if (resend != true) return;
    try {
      await authService.resendVerification(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text.verbatim('$e')));
      }
    }
  }

  // "Forgot password?": email a reset link
  Future<void> _forgotPassword() async {
    final c = TextEditingController(text: _emailController.text.trim());
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: tr(ctx, 'Email Address')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send reset link')),
        ],
      ),
    );
    final email = c.text.trim();
    c.dispose();
    if (send != true || email.isEmpty) return;
    try {
      await authService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'If that email has an account, a reset link is on its way.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text.verbatim('$e')));
      }
    }
  }

  // dispose controllers
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Build User Interface
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
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
            TextFormField(
              controller: _emailController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: tr(context, "Email Address"),
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Geist'
                ),
                filled: true,
                fillColor: AppColors.field(context),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // password
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: tr(context, "Password"),
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Geist'
                ),
                filled: true,
                fillColor: AppColors.field(context),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
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
              )
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _forgotPassword,
                child: const Text('Forgot password?',
                    style: TextStyle(
                        color: Color(0xFF3C6E87), fontFamily: 'Geist')),
              ),
            ),

            // button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3C6E87),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isLoading ? null : login,
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
              onTap: _isLoading
                ? null
                : () { Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const RoleSelectPage())
                  );
                },
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