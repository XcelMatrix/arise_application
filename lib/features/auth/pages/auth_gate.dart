import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/features/auth/pages/login_page.dart';
import 'package:arise_application/features/home/pages/home_page.dart';

/// Decides what to show when the app opens: the login page when nobody is
/// signed in, otherwise Home (which itself shows the "waiting for approval"
/// screen to teachers who are not approved yet).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            auth.currentSession == null &&
            !snapshot.hasData) {
          // first moment: the session is still being restored
          return const Scaffold(body: FlashingLogo());
        }
        final session = snapshot.data?.session ?? auth.currentSession;
        return session == null ? const LoginPage() : const HomePage();
      },
    );
  }
}
