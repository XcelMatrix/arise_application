import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/announcements/models/announcement.dart';

class TeacherRequest {
  final String userId;
  final String status; // pending / approved / rejected
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String name;
  final String username;

  const TeacherRequest({
    required this.userId,
    required this.status,
    required this.requestedAt,
    required this.name,
    required this.username,
    this.reviewedAt,
  });

  factory TeacherRequest.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    final p = profile is List ? (profile.isEmpty ? null : profile.first) : profile;
    return TeacherRequest(
      userId: row['user_id'] as String,
      status: row['status'] as String,
      requestedAt:
          DateTime.tryParse('${row['requested_at']}')?.toLocal() ?? DateTime.now(),
      reviewedAt: row['reviewed_at'] == null
          ? null
          : DateTime.tryParse('${row['reviewed_at']}')?.toLocal(),
      name: shownNameFromProfile(profile),
      username: p is Map ? (p['username'] as String? ?? '') : '',
    );
  }
}

class TeacherRequestsState {
  final bool loaded;
  final List<TeacherRequest> requests;
  final String? error;

  const TeacherRequestsState({
    this.loaded = false,
    this.requests = const [],
    this.error,
  });

  List<TeacherRequest> get pending =>
      requests.where((r) => r.status == 'pending').toList();

  List<TeacherRequest> get decided =>
      requests.where((r) => r.status != 'pending').toList();
}

/// Teacher sign-ups waiting for approval. Only loads for accounts that may
/// review them (07_teacher_review.sql enforces the same rule in the database).
class TeacherRequestsCubit extends Cubit<TeacherRequestsState> {
  TeacherRequestsCubit(this._account) : super(const TeacherRequestsState()) {
    _accountSub = _account.stream.listen(_onAccount);
    _onAccount(_account.state);
  }

  final AccountCubit _account;
  final _sb = Supabase.instance.client;
  StreamSubscription<AccountState>? _accountSub;
  RealtimeChannel? _channel;
  String? _uid;

  void _onAccount(AccountState a) {
    final uid = _sb.auth.currentUser?.id;
    if (uid != _uid) {
      _stop();
      _uid = uid;
      if (!isClosed) emit(const TeacherRequestsState());
    }
    final allowed = uid != null && a.loaded && a.canAccess(Feature.teacherReview);
    if (allowed) {
      load();
    } else {
      _stop();
      if (!isClosed && state.loaded) emit(const TeacherRequestsState());
    }
  }

  Future<void> load() async {
    _channel ??= _sb
        .channel('teacher-requests-list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teacher_requests',
          callback: (_) => _fetch(),
        )
        .subscribe();
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final rows = await _sb
          .from('teacher_requests')
          .select('*, profiles(username, profile_details(display_name))')
          .order('requested_at', ascending: false)
          .limit(100);
      if (isClosed) return;
      emit(TeacherRequestsState(
        loaded: true,
        requests: [
          for (final r in rows)
            TeacherRequest.fromRow(Map<String, dynamic>.from(r)),
        ],
      ));
    } catch (e) {
      if (!isClosed) {
        emit(TeacherRequestsState(
            loaded: true, requests: state.requests, error: '$e'));
      }
    }
  }

  void _stop() {
    final c = _channel;
    _channel = null;
    if (c != null) _sb.removeChannel(c);
  }

  Future<void> _decide(String userId, String status) async {
    final rows = await _sb
        .from('teacher_requests')
        .update({'status': status})
        .eq('user_id', userId)
        .select();
    if (rows.isEmpty) throw 'You are not allowed to review this request.';
    await _fetch();
  }

  Future<void> approve(String userId) => _decide(userId, 'approved');
  Future<void> reject(String userId) => _decide(userId, 'rejected');

  @override
  Future<void> close() {
    _accountSub?.cancel();
    _stop();
    return super.close();
  }
}
