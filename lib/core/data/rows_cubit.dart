import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/services/local_cache.dart';

class RowsState {
  final bool loaded;
  final List<Map<String, dynamic>> rows;

  /// true when these rows are the saved copy (no connection)
  final bool offline;
  const RowsState({this.loaded = false, this.rows = const [], this.offline = false});
}

/// Loads a whole table live, keeps a saved copy for offline use and does
/// simple add / edit / delete. Used for guidelines, emergency contacts and
/// each teacher's saved class lists.
class RowsCubit extends Cubit<RowsState> {
  RowsCubit(this.table,
      {required this.orderBy, this.perUser = false, this.ascending = true})
      : super(const RowsState()) {
    _authSub = _sb.auth.onAuthStateChange.listen((d) {
      if (d.session != null) {
        load();
      } else {
        _channel?.unsubscribe();
        _channel = null;
        if (!isClosed) emit(const RowsState());
      }
    });
  }

  final String table;
  final List<String> orderBy;
  final bool perUser;
  final bool ascending;

  final _sb = Supabase.instance.client;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;

  String get _cacheKey => perUser ? '${table}_${_sb.auth.currentUser?.id}' : table;

  Future<void> load() async {
    if (_sb.auth.currentUser == null) return;
    try {
      var q = _sb.from(table).select();
      PostgrestTransformBuilder<PostgrestList> t = q;
      for (final o in orderBy) {
        t = t.order(o, ascending: ascending);
      }
      final rows = [for (final r in await t) Map<String, dynamic>.from(r)];
      await LocalCache.save(_cacheKey, rows);
      if (!isClosed) emit(RowsState(loaded: true, rows: rows));
      _listen();
    } catch (_) {
      final cached = await LocalCache.readRows(_cacheKey);
      if (!isClosed) {
        emit(RowsState(loaded: true, rows: cached ?? state.rows, offline: true));
      }
    }
  }

  void _listen() {
    if (_channel != null) return;
    _channel = _sb
        .channel('rows-$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => load(),
        )
        .subscribe();
  }

  Future<void> add(Map<String, dynamic> values) async {
    await _sb.from(table).insert(values);
    await load();
  }

  /// Adds a row without reloading and returns its id (the caller reloads).
  Future<String> insertRow(Map<String, dynamic> values) async {
    final r = await _sb.from(table).insert(values).select('id').single();
    return r['id'] as String;
  }

  /// Saves a new order: ids[0] gets sort_order 1, ids[1] gets 2, and so on.
  /// Only rows whose number changed are written.
  Future<void> reorder(List<String> ids) async {
    final cur = {
      for (final r in state.rows)
        r['id'] as String: (r['sort_order'] as num?)?.toInt() ?? 0
    };
    final writes = <Future<void>>[];
    for (var i = 0; i < ids.length; i++) {
      if (cur[ids[i]] == i + 1) continue;
      final id = ids[i];
      final n = i + 1;
      writes.add(() async {
        await _sb.from(table).update({'sort_order': n}).eq('id', id);
      }());
    }
    await Future.wait(writes);
    await load();
  }

  Future<void> edit(String id, Map<String, dynamic> values) async {
    final r = await _sb.from(table).update(values).eq('id', id).select();
    if (r.isEmpty) throw 'You are not allowed to change this.';
    await load();
  }

  Future<void> remove(String id) async {
    final r = await _sb.from(table).delete().eq('id', id).select();
    if (r.isEmpty) throw 'You are not allowed to delete this.';
    await load();
  }

  @override
  Future<void> close() {
    _channel?.unsubscribe();
    _authSub?.cancel();
    return super.close();
  }
}
