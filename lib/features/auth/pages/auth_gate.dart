import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/features/auth/pages/login_page.dart';
import 'package:arise_application/features/help/pages/tour_page.dart';
import 'package:arise_application/features/home/pages/home_page.dart';
import 'package:arise_application/features/account/widgets/class_gate.dart';

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
        return session == null ? const _SignedOut() : const ClassGate(child: HomePage());
      },
    );
  }
}

/// Signed out: the intro the very first time, then the login page.
class _SignedOut extends StatefulWidget {
  const _SignedOut();

  @override
  State<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends State<_SignedOut> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    TourPage.alreadySeen().then((v) {
      if (mounted) setState(() => _seen = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final seen = _seen;
    if (seen == null) return const Scaffold(body: FlashingLogo());
    if (!seen) return TourPage(onDone: () => setState(() => _seen = true));
    return const LoginPage();
  }
}
