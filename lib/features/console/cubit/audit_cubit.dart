import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/services/local_cache.dart';

class AuditEntry {
  final int id;
  final DateTime time;
  final String actor;
  final String action;
  final String? detail;
  const AuditEntry(this.id, this.time, this.actor, this.action, this.detail);

  factory AuditEntry.fromRow(Map<String, dynamic> r) => AuditEntry(
        (r['id'] as num).toInt(),
        DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now(),
        (r['actor_name'] as String?) ?? 'System',
        r['action'] as String,
        r['detail'] as String?,
      );
}

class AuditState {
  final bool loaded;
  final List<AuditEntry> entries;
  final bool offline;
  const AuditState(
      {this.loaded = false, this.entries = const [], this.offline = false});
}

/// Read-only audit log (newest first). Written by database triggers only.
class AuditCubit extends Cubit<AuditState> {
  AuditCubit() : super(const AuditState()) {
    _sb.auth.onAuthStateChange.listen((d) {
      if (d.session == null) {
        _channel?.unsubscribe();
        _channel = null;
        if (!isClosed) emit(const AuditState());
      }
    });
  }

  final _sb = Supabase.instance.client;
  RealtimeChannel? _channel;

  Future<void> load() async {
    if (_sb.auth.currentUser == null) return;
    try {
      final rows = await _sb
          .from('audit_log')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      await LocalCache.save('audit_log', rows);
      if (!isClosed) {
        emit(AuditState(loaded: true, entries: [
          for (final r in rows) AuditEntry.fromRow(Map<String, dynamic>.from(r)),
        ]));
      }
      _channel ??= _sb
          .channel('audit-log')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'audit_log',
            callback: (_) => load(),
          )
          .subscribe();
    } catch (_) {
      final cached = await LocalCache.readRows('audit_log');
      if (!isClosed) {
        emit(AuditState(loaded: true, offline: true, entries: [
          for (final r in cached ?? const <Map<String, dynamic>>[])
            AuditEntry.fromRow(r),
        ]));
      }
    }
  }

  @override
  Future<void> close() {
    _channel?.unsubscribe();
    return super.close();
  }
}
