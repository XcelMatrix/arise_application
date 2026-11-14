import 'package:supabase_flutter/supabase_flutter.dart';

/// Deep link Supabase opens after the person taps an email link.
/// Add it under Authentication > URL Configuration > Redirect URLs.
const authRedirect = 'io.supabase.arise://login-callback/';

class AuthService {
  /// Password rule used when signing up, resetting and changing a password.
  /// Returns the message to show, or null when the password is fine.
  static String? passwordProblem(String pw) {
    if (pw.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(pw) ||
        !RegExp(r'[0-9]').hasMatch(pw)) {
      return 'Use at least 8 characters with a letter and a number.';
    }
    return null;
  }

  /// Is the signed-in person's email address verified?
  bool get emailVerified =>
      Supabase.instance.client.auth.currentUser?.emailConfirmedAt != null;

  String? get email => Supabase.instance.client.auth.currentUser?.email;

  /// Start an email change. Supabase emails a confirmation link; the address
  /// only changes after it is opened.
  Future<void> changeEmail(String newEmail) async {
    await _supabaseClient.auth.updateUser(
      UserAttributes(email: newEmail.trim()),
      emailRedirectTo: authRedirect,
    );
  }

  final SupabaseClient _supabaseClient = Supabase.instance.client;
  
  // Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword (String email, String password) async {
    return await _supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );

  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword (
    String email,
    String password,
    String username, {
    String? requestedRole,
  }) async {
    return await _supabaseClient.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: authRedirect,
      data: {
        'username': username,
        // only creates a PENDING request; the database never trusts this for access
        'requested_role': ?requestedRole,
      },
    );
  }

  // Email a password-reset link
  Future<void> sendPasswordReset(String email) async {
    await _supabaseClient.auth
        .resetPasswordForEmail(email.trim(), redirectTo: authRedirect);
  }

  // Set a new password (after opening the reset link)
  Future<void> setNewPassword(String password) async {
    await _supabaseClient.auth.updateUser(UserAttributes(password: password));
  }

  // Send the verification email again
  Future<void> resendVerification(String email) async {
    await _supabaseClient.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: authRedirect,
    );
  }

  // Check the current password (used before changing it or deleting the account)
  Future<void> confirmPassword(String password) async {
    final email = _supabaseClient.auth.currentUser?.email;
    if (email == null) throw 'Not signed in';
    await _supabaseClient.auth
        .signInWithPassword(email: email, password: password);
  }

  // Permanently delete the signed-in account (see 12_buildings_retention_admin.sql)
  Future<void> deleteMyAccount() async {
    await _supabaseClient.rpc('delete_my_account');
    try {
      await _supabaseClient.auth.signOut();
    } catch (_) {
      // the account is already gone, nothing left to sign out of
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  // Get user email
  String? getCurrentUserEmail() {
    final session = _supabaseClient.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  String? getCurrentUsername() {
    final session = _supabaseClient.auth.currentSession;
    final user = session?.user;
    return user?.userMetadata?['username'] as String?;
  }
}