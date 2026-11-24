import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/auth/services/auth_service.dart';
import 'package:arise_application/features/auth/utils/auth_validators.dart';
import 'package:arise_application/features/auth/pages/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.isTeacher = false});

  /// true = teacher request (needs approval), false = normal student account
  final bool isTeacher;

  static Route<void> route({bool isTeacher = false}) {
    return MaterialPageRoute(
        builder: (context) => RegisterPage(isTeacher: isTeacher));
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

  final _formKey = GlobalKey<FormState>();

  // text controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  //sign up button pressed
  void signUp() async {
    // prepare data
    // run every field's check first
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final username = AuthValidators.cleanUsername(_usernameController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // set loading state
    setState(() {
      _isLoading = true;
    });

    // attempt sign up..
    try {
      // usernames are unique (capitals do not matter)
      if (!await authService.usernameAvailable(username)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr(context,
                  'That username is already taken. Please pick another one.'))));
          setState(() => _isLoading = false);
        }
        return;
      }
      final res = await authService.signUpWithEmailPassword(
        email,
        password,
        username,
        requestedRole: widget.isTeacher ? 'teacher' : null,
      );

      if (!mounted) return;

      // no session yet = the project asks for the email to be verified first
      final needsVerify = res.session == null;
      if (needsVerify || widget.isTeacher) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(needsVerify ? 'Verify your email' : 'Request sent'),
            content: Text(
              [
                if (needsVerify)
                  'We sent a verification link to your email. Open it, then log in.',
                if (widget.isTeacher)
                  'Your teacher account has to be approved before you can use it. '
                      'Sign in again once you have been approved.',
              ].join('\n\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }

      // back to the root (AuthGate decides login vs home)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } 

    // catch any errors
    catch (error) { 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))));
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

  /// Turns a sign-up failure into a short, readable message.
  String _friendlyError(Object error) {
    final text = (error is AuthException ? error.message : '$error').toLowerCase();
    if (text.contains('too many') || text.contains('rate limit')) {
      return tr(context, 'Too many attempts. Please wait a minute and try again.');
    }
    if (text.contains('already registered') || text.contains('already exists')) {
      return tr(context, 'An account with that email already exists. Try logging in.');
    }
    if (text.contains('username')) {
      return tr(context, 'That username is not available. Please pick another one.');
    }
    if (text.contains('password')) {
      return tr(context, 'That password was not accepted. Choose a stronger one.');
    }
    if (text.contains('socket') || text.contains('network') || text.contains('host lookup')) {
      return tr(context, 'No internet connection. Please try again.');
    }
    return tr(context, 'Could not create the account. Please try again.');
  }

  // dispose controllers
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3C6E87)),
        leading: BackButton(
          onPressed: _isLoading ? null : () => Navigator.maybePop(context),
        ),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                widget.isTeacher ? "Teacher Sign Up" : "Sign Up", 
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF3C6E87),
                  fontFamily: 'Geist'
                )
              )
            ),

            const SizedBox(height: 32),

            if (widget.isTeacher) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.soft(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Teacher accounts need approval before they can be used. '
                  'You can sign in once you have been approved.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF3C6E87),
                    fontFamily: 'Geist',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            //username
            TextFormField(
              style: const TextStyle(
                  color: Color(0xFF3C6E87), fontFamily: 'Geist', fontSize: 16),
              controller: _usernameController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: tr(context, "Username"),
                counterText: '',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Color(0x993C6E87),
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
              ),

              validator: AuthValidators.username,
              inputFormatters: [
                TextInputFormatter.withFunction((old, v) => v.copyWith(
                    text: v.text.toLowerCase())),
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              maxLength: 24,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 8),

            //email
            TextFormField(
              style: const TextStyle(
                  color: Color(0xFF3C6E87), fontFamily: 'Geist', fontSize: 16),
              controller: _emailController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: tr(context, "Email Address"),
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Color(0x993C6E87),
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
              ),
              
              validator: AuthValidators.email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 8),

            //password
            TextFormField(
              style: const TextStyle(
                  color: Color(0xFF3C6E87), fontFamily: 'Geist', fontSize: 16),
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: tr(context, "Password"),
                counterText: '',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Color(0x993C6E87),
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
                    color: Color(0xFF3C6E87),
                  ),
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),

              validator: (val) => AuthValidators.password(val,
                  username: _usernameController.text,
                  email: _emailController.text),
              maxLength: 72,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 8),

            //confirm password
            TextFormField(
              style: const TextStyle(
                  color: Color(0xFF3C6E87), fontFamily: 'Geist', fontSize: 16),
              controller: _confirmPasswordController,
              enabled: !_isLoading,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: tr(context, "Confirm Password"),
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Color(0x993C6E87),
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
                    color: Color(0xFF3C6E87),
                  ),
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              validator: (val) => val == _passwordController.text
                  ? null
                  : Tr.t('Passwords do not match'),
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
            ),

            const SizedBox(height: 24),

            // go to login page to login
            GestureDetector(
              onTap: _isLoading
                ? null
                : () { Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const LoginPage())
                  );
                },
              child: const Center(child: Text(
                "Already have an account?",
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
        )
      ),
    );
  }
}