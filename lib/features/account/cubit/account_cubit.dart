import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Feature keys. They match the rows in public.feature_access.
class Feature {
  static const attendance = 'attendance';
  static const timedConsole = 'timed_console';
  static const chat = 'chat';
  // teachers + admins may add / edit calendar events (everyone can view)
  static const calendarEdit = 'calendar_edit';
  // teachers + admins may post announcements
  static const announce = 'announce';
  // teachers + admins may approve / decline teacher sign-ups
  static const teacherReview = 'teacher_review';
  static const contentEdit = 'content_edit';
  static const mapEdit = 'map_edit';
  static const auditLog = 'audit_log';
  static const emergencyAlert = 'emergency_alert';
}

class AccountState {
  final bool loaded;
  final String roleName;
  final int rank; // 0 = no role found
  final String? username; // the handle the app uses (from register page)
  final String? displayName; // what people see (editable on profile page)
  final String? avatarUrl;
  final Map<String, int> featureMinRank;

  /// 'pending' | 'approved' | 'rejected' for teacher sign-ups, else null.
  final String? teacherRequestStatus;

  const AccountState({
    this.loaded = false,
    this.roleName = '',
    this.rank = 0,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.featureMinRank = const {},
    this.teacherRequestStatus,
  });

  /// Teacher who isn't approved yet (or was declined): app stays locked.
  bool get isTeacherPending =>
      teacherRequestStatus == 'pending' || teacherRequestStatus == 'rejected';

  /// Display name if set, otherwise falls back to the username.
  String get shownName {
    final d = displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    return username ?? 'User';
  }

  bool canAccess(String feature) {
    final min = featureMinRank[feature];
    if (min == null) return false;
    return rank >= min;
  }

  AccountState copyWith({
    bool? loaded,
    String? roleName,
    int? rank,
    String? username,
    String? displayName,
    String? avatarUrl,
    Map<String, int>? featureMinRank,
    String? teacherRequestStatus,
    bool clearDisplayName = false,
    bool clearAvatar = false,
  }) =>
      AccountState(
        loaded: loaded ?? this.loaded,
        roleName: roleName ?? this.roleName,
        rank: rank ?? this.rank,
        username: username ?? this.username,
        displayName: clearDisplayName ? null : (displayName ?? this.displayName),
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
        featureMinRank: featureMinRank ?? this.featureMinRank,
        teacherRequestStatus: teacherRequestStatus ?? this.teacherRequestStatus,
      );
}

class AccountCubit extends Cubit<AccountState> {
  AccountCubit() : super(const AccountState()) {
    _authSub = _sb.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        emit(const AccountState());
      } else if (data.session != null &&
          (data.event == AuthChangeEvent.signedIn ||
              data.event == AuthChangeEvent.initialSession ||
              data.event == AuthChangeEvent.userUpdated)) {
        load();
      }
    });
  }

  final _sb = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;
  bool _loading = false;

  String? get _uid => _sb.auth.currentUser?.id;

  Future<void> load() async {
    final uid = _uid;
    if (uid == null || _loading) return;
    _loading = true;
    try {
      final profile = await _sb
          .from('profiles')
          .select('username')
          .eq('id', uid)
          .maybeSingle();

      final roleRow = await _sb
          .from('user_roles')
          .select('roles(name, rank)')
          .eq('user_id', uid)
          .maybeSingle();
      final role = roleRow?['roles'] as Map<String, dynamic>?;

      final details = await _sb
          .from('profile_details')
          .select('display_name, avatar_url')
          .eq('user_id', uid)
          .maybeSingle();

      final request = await _sb
          .from('teacher_requests')
          .select('status')
          .eq('user_id', uid)
          .maybeSingle();

      final features = await _sb.from('feature_access').select();

      if (isClosed) return;
      emit(AccountState(
        loaded: true,
        roleName: role?['name'] as String? ?? 'none',
        rank: role?['rank'] as int? ?? 0,
        username: profile?['username'] as String?,
        displayName: details?['display_name'] as String?,
        avatarUrl: details?['avatar_url'] as String?,
        teacherRequestStatus: request?['status'] as String?,
        featureMinRank: {
          for (final f in features)
            f['feature'] as String: f['min_rank'] as int,
        },
      ));
    } catch (_) {
      // Fail closed: loaded but no access.
      if (!isClosed) emit(state.copyWith(loaded: true, rank: 0));
    } finally {
      _loading = false;
    }
  }

  /// Create or edit the display name. Empty clears it (falls back to username).
  Future<void> saveDisplayName(String name) async {
    final uid = _uid;
    if (uid == null) return;
    final trimmed = name.trim();
    await _sb.from('profile_details').upsert({
      'user_id': uid,
      'display_name': trimmed.isEmpty ? null : trimmed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    emit(trimmed.isEmpty
        ? state.copyWith(clearDisplayName: true)
        : state.copyWith(displayName: trimmed));
  }

  /// Add or replace the profile picture.
  Future<void> uploadAvatar(XFile file) async {
    final uid = _uid;
    if (uid == null) return;
    final bytes = await file.readAsBytes();
    final path = '$uid/avatar';

    await _sb.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: file.mimeType ?? 'image/jpeg',
          ),
        );

    // cache-bust so the new picture shows right away
    final url =
        '${_sb.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';

    await _sb.from('profile_details').upsert({
      'user_id': uid,
      'avatar_url': url,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    emit(state.copyWith(avatarUrl: url));
  }

  Future<void> removeAvatar() async {
    final uid = _uid;
    if (uid == null) return;
    await _sb.storage.from('avatars').remove(['$uid/avatar']);
    await _sb.from('profile_details').upsert({
      'user_id': uid,
      'avatar_url': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    emit(state.copyWith(clearAvatar: true));
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
