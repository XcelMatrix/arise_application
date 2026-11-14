import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/alerts/services/background_alerts.dart';
import 'package:arise_application/translations/translation.dart';

/// The standard message for each type of emergency (English). Every language
/// file translates these sentences, so each phone shows the alert in the
/// language picked in Settings. "Other" has no standard message: the sender
/// types it and it is shown as typed.
const alertTemplates = {
  'Fire': 'Fire reported. Evacuate now using the nearest safe exit and go to your evacuation site.',
  'Earthquake': 'Earthquake. Drop, cover and hold on. Evacuate to the open area once the shaking stops.',
  'Flood': 'Flooding. Move to higher ground and wait for instructions.',
  'Typhoon': 'Typhoon warning. Stay indoors and away from windows.',
  'Lockdown': 'Lockdown. Lock doors, stay quiet and stay away from windows until the all-clear.',
  'Other': '',
};

class EmergencyAlert {
  final String id;
  final String kind;
  final String message;
  final String senderName;
  final DateTime createdAt;

  /// optional extra line from the sender (e.g. "Building B"), shown as typed
  final String details;

  /// only on alerts sent by an older version: {'fil': '...'}
  final Map<String, String> translations;

  /// when staff last reminded people who had not answered (null = never)
  final DateTime? remindedAt;
  const EmergencyAlert(
      this.id, this.kind, this.message, this.senderName, this.createdAt,
      [this.translations = const {}, this.details = '', this.remindedAt]);

  factory EmergencyAlert.fromRow(Map<String, dynamic> r) => EmergencyAlert(
        r['id'] as String,
        r['kind'] as String,
        r['message'] as String,
        (r['sender_name'] as String?) ?? '',
        DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now(),
        parseAlertTranslations(r['translations']),
        ((r['details'] as String?) ?? '').trim(),
        r['reminded_at'] == null
            ? null
            : DateTime.tryParse('${r['reminded_at']}')?.toLocal(),
      );

  /// The message in the language picked in Settings (falls back to the
  /// original text when the sender did not write that language).
  String get localMessage {
    final m = localizedAlertMessage(message, translations);
    return details.isEmpty ? m : '$m\n$details';
  }

  /// "Fire" -> "Sunog" when Filipino is picked.
  String get localKind => Tr.t(kind);
}

Map<String, String> parseAlertTranslations(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if ('${e.value}'.trim().isNotEmpty) '${e.key}': '${e.value}',
  };
}

/// The whole alert text for a row of the emergency_alerts table in the
/// current language: the standard message translated, plus the details line.
String localizedAlertRow(Map<String, dynamic> r) {
  final msg = localizedAlertMessage(
      '${r['message']}', parseAlertTranslations(r['translations']));
  final d = '${r['details'] ?? ''}'.trim();
  return d.isEmpty ? msg : '$msg\n$d';
}

/// Picks the text for the current language: what the sender wrote for it,
/// otherwise a built-in translation of the standard messages, otherwise
/// the original message.
String localizedAlertMessage(String message, Map<String, String> translations) {
  final code = Tr.current.code;
  final written = translations[code];
  if (written != null && written.trim().isNotEmpty) return written;
  return Tr.t(message);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // coming back from the background (e.g. from the push notification)
    AlertBackground.setAppForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    if (_sb.auth.currentUser == null) return;
    String? stored;
    try {
      stored = (await SharedPreferences.getInstance()).getString(_prefKey);
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
      // read the dismissed id NOW, not before the request: the person may
      // have tapped "I understand" (or sent the alert) while we were waiting
      emit(AlertState(
          active: fresh ? a : null, dismissedId: state.dismissedId ?? stored));
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

  /// Show the full warning again (a reminder for someone who has not answered).
  Future<void> reshow() async {
    final a = state.active;
    if (a == null) return;
    try {
      await (await SharedPreferences.getInstance()).remove(_prefKey);
    } catch (_) {}
    if (!isClosed) emit(AlertState(active: a, dismissedId: null));
  }

  Future<void> dismiss() async {
    final id = state.active?.id;
    if (id == null) return;
    emit(AlertState(active: state.active, dismissedId: id));
    try {
      await (await SharedPreferences.getInstance()).setString(_prefKey, id);
    } catch (_) {}
  }

  Future<void> send(String kind, String message, [String details = '']) async {
    final id = await _sb.rpc('send_alert', params: {
      'p_kind': kind,
      'p_message': message,
      'p_details': details,
    }) as String;
    // the sender does not need the full-screen alert: mark it as seen BEFORE
    // anything reloads, otherwise the realtime reload shows it again
    emit(AlertState(active: state.active, dismissedId: id));
    try {
      await (await SharedPreferences.getInstance()).setString(_prefKey, id);
    } catch (_) {}
    await load();
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
