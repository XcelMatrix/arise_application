import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyAlert {
  final String id;
  final String kind;
  final String message;
  final String senderName;
  final DateTime createdAt;
  const EmergencyAlert(
      this.id, this.kind, this.message, this.senderName, this.createdAt);

  factory EmergencyAlert.fromRow(Map<String, dynamic> r) => EmergencyAlert(
        r['id'] as String,
        r['kind'] as String,
        r['message'] as String,
        (r['sender_name'] as String?) ?? '',
        DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

class AlertState {
  /// the alert that is still active (not cleared), if any
  final EmergencyAlert? active;

  /// id of the alert this device already acknowledged
  final String? dismissedId;
  const AlertState({this.active, this.dismissedId});

  bool get showing => active != null && active!.id != dismissedId;
}

/// Emergency alerts: everyone receives them, only teachers/admins send.
/// The database enforces who may send (see 10_emergency_alerts.sql).
class AlertCubit extends Cubit<AlertState> with WidgetsBindingObserver {
  AlertCubit() : super(const AlertState()) {
    WidgetsBinding.instance.addObserver(this);
    _authSub = _sb.auth.onAuthStateChange.listen((d) {
      if (d.session != null) {
        load();
      } else {
        _channel?.unsubscribe();
        _channel = null;
        if (!isClosed) emit(const AlertState());
      }
    });
    if (_sb.auth.currentUser != null) load();
  }

  static const _prefKey = 'arise_alert_dismissed';
  final _sb = Supabase.instance.client;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // coming back from the background (e.g. from the push notification)
    if (s == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    if (_sb.auth.currentUser == null) return;
    String? dismissed = state.dismissedId;
    try {
      dismissed ??= (await SharedPreferences.getInstance()).getString(_prefKey);
    } catch (_) {}
    try {
      final rows = await _sb
          .from('emergency_alerts')
          .select()
          .isFilter('cleared_at', null)
          .order('created_at', ascending: false)
          .limit(1);
      if (isClosed) return;
      // alerts older than a day are stale (e.g. someone forgot to clear)
      final a = rows.isEmpty
          ? null
          : EmergencyAlert.fromRow(Map<String, dynamic>.from(rows.first));
      final fresh = a != null &&
          DateTime.now().difference(a.createdAt) < const Duration(hours: 24);
      emit(AlertState(active: fresh ? a : null, dismissedId: dismissed));
      _channel ??= _sb
          .channel('emergency-alerts')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'emergency_alerts',
            callback: (_) => load(),
          )
          .subscribe();
    } catch (_) {
      // offline: keep whatever is already showing
    }
  }

  Future<void> dismiss() async {
    final id = state.active?.id;
    if (id == null) return;
    emit(AlertState(active: state.active, dismissedId: id));
    try {
      await (await SharedPreferences.getInstance()).setString(_prefKey, id);
    } catch (_) {}
  }

  Future<void> send(String kind, String message) async {
    final id = await _sb.rpc('send_alert',
        params: {'p_kind': kind, 'p_message': message}) as String;
    await load();
    await dismiss(); // the sender does not need the full-screen alert
    assert(id.isNotEmpty);
  }

  Future<void> clear(String id) async {
    await _sb.rpc('clear_alert', params: {'p_id': id});
    await load();
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _authSub?.cancel();
    return super.close();
  }
}
