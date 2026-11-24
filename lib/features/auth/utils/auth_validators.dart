import 'package:arise_application/features/auth/services/auth_service.dart';
import 'package:arise_application/translations/translation.dart';

/// The rules for usernames, emails and passwords. The same rules are checked
/// again by the database (30_username_security.sql), so they cannot be skipped.
class AuthValidators {
  /// Names nobody may take (they could be mistaken for staff or the system).
  static const reserved = {
    'admin', 'administrator', 'root', 'system', 'support', 'arise', 'staff',
    'moderator', 'mod', 'owner', 'official', 'teacher', 'student', 'help',
    'info', 'security', 'superuser', 'null', 'undefined', 'anonymous',
    'deleted', 'unknown', 'everyone', 'all',
  };

  static const _weakPasswords = {
    'password1', 'password12', 'password123', 'password1234', 'qwerty123',
    'qwerty1234', 'abc12345', 'abcd1234', 'iloveyou1', 'welcome1', 'welcome123',
    'admin123', 'letmein123', 'arise1234', 'arise123', '12345678a', 'a1234567',
    'a12345678', 'p@ssw0rd', 'passw0rd',
  };

  /// A username as people type it: trimmed.
  static String cleanUsername(String v) => v.trim().toLowerCase();

  /// null = fine, otherwise the (translated) message to show.
  static String? username(String? value) {
    final raw = (value ?? '').trim();
    final v = cleanUsername(raw);
    if (v.isEmpty) return Tr.t('Required');
    if (raw != raw.toLowerCase()) return Tr.t('Use lowercase letters only.');
    if (v.length < 3 || v.length > 24) return Tr.t('3-24 characters long.');
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(v)) {
      return Tr.t('Start with a letter. Use only lowercase letters, numbers and underscores.');
    }
    if (v.contains('__')) return Tr.t('Use only one underscore in a row.');
    if (reserved.contains(v.toLowerCase())) {
      return Tr.t('That username is not available.');
    }
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return Tr.t('Required');
    if (v.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v)) {
      return Tr.t('Enter a valid email address.');
    }
    return null;
  }

  static String? password(String? value,
      {String username = '', String email = ''}) {
    final v = value ?? '';
    if (v.isEmpty) return Tr.t('Required');
    final basic = AuthService.passwordProblem(v);
    if (basic != null) return Tr.t(basic);
    if (v.length > 72) return Tr.t('Use at most 72 characters.');
    final lower = v.toLowerCase();
    if (_weakPasswords.contains(lower) ||
        RegExp(r'^(.)\1+$').hasMatch(v)) {
      return Tr.t('That password is too common. Choose a harder one.');
    }
    final u = username.trim().toLowerCase();
    final e = email.trim().toLowerCase();
    if ((u.length >= 3 && lower == u) ||
        (e.isNotEmpty && (lower == e || lower == e.split('@').first))) {
      return Tr.t('Do not use your username or email as your password.');
    }
    return null;
  }
}
