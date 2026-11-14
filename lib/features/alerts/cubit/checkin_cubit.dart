import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';

class CheckInState {
  /// the alert this answer belongs to
  final String? alertId;

  /// 'safe' | 'help' | null (not answered yet)
  final String? status;

  /// true while the answer is saved on the phone and waiting for a connection
  final bool waiting;
  const CheckInState({this.alertId, this.status, this.waiting = false});
}

/// "I'm safe" / "I need help" for the alert that is showing. When there is
/// no signal the answer is kept on the phone and sent as soon as the
/// connection returns.
class CheckInCubit extends Cubit<CheckInState> {
  CheckInCubit(this._alerts) : super(const CheckInState()) {
    _sub = _alerts.stream.listen((s) {
      final id = s.active?.id;
      if (id != state.alertId) {
        emit(CheckInState(alertId: id));
        if (id != null) load();
      }
      final a = s.active;
      if (a != null && a.remindedAt != null) _onReminder(a);
    });
    final id = _alerts.state.active?.id;
    if (id != null) {
      emit(CheckInState(alertId: id));
      load();
    }
  }

  static const _pendingKey = 'arise_checkin_pending';
  static const _answeredKey = 'arise_checkin_alert'; // read by the background service
  static const _remindedKey = 'arise_alert_reminded';
  final AlertCubit _alerts;
  String? _handling; // reminder being handled (the stream fires often)
  StreamSubscription<AlertState>? _sub;
  final _sb = Supabase.instance.client;

  /// Staff reminded everyone who has not answered: show the warning again
  /// to this person unless they already answered.
  Future<void> _onReminder(EmergencyAlert a) async {
    final stamp = '${a.id}|${a.remindedAt!.toUtc().toIso8601String()}';
    if (_handling == stamp) return;
    _handling = stamp;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_remindedKey) == stamp) return; // already handled
      await prefs.setString(_remindedKey, stamp);
    } catch (_) {}
    await load(); // ask the server what this person answered
    if (isClosed || state.alertId != a.id) return;
    if (state.status == null) await _alerts.reshow();
  }

  /// What this person already answered for the active alert.
  Future<void> load() async {
    final id = state.alertId;
    final uid = _sb.auth.currentUser?.id;
    if (id == null || uid == null) return;
    await flush();
    try {
      final row = await _sb
          .from('safe_checkins')
          .select('status')
          .eq('alert_id', id)
          .eq('user_id', uid)
          .maybeSingle();
      if (isClosed || state.alertId != id) return;
      final answered = row?['status'] as String?;
      if (answered != null) await _rememberAnswered(id);
      emit(CheckInState(alertId: id, status: answered, waiting: state.waiting));
    } catch (_) {
      // offline: keep what we know
    }
  }

  Future<void> submit(String status) async {
    final id = state.alertId;
    if (id == null) return;
    emit(CheckInState(alertId: id, status: status, waiting: true));
    await _rememberAnswered(id);
    try {
      await _sb.rpc('check_in', params: {'p_alert': id, 'p_status': status});
      await _clearPending();
      if (!isClosed) emit(CheckInState(alertId: id, status: status));
    } catch (e) {
      if (e is PostgrestException) {
        // the server said no (e.g. the alert was removed): do not retry
        if (!isClosed) emit(CheckInState(alertId: id));
        rethrow;
      }
      await _savePending(id, status); // no signal: send it later
    }
  }

  /// Send an answer that was waiting for a connection.
  Future<void> flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null || _sb.auth.currentUser == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      await _sb.rpc('check_in',
          params: {'p_alert': m['alert'], 'p_status': m['status']});
      await prefs.remove(_pendingKey);
      if (!isClosed && state.alertId == m['alert']) {
        emit(CheckInState(alertId: state.alertId, status: state.status));
      }
    } on PostgrestException {
      await _clearPending(); // rejected: drop it
    } catch (_) {
      // still offline
    }
  }

  Future<void> _rememberAnswered(String alertId) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_answeredKey, alertId);
    } catch (_) {}
  }

  Future<void> _savePending(String alert, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _pendingKey, jsonEncode({'alert': alert, 'status': status}));
    } catch (_) {}
  }

  Future<void> _clearPending() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_pendingKey);
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
