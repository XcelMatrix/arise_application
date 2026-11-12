import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/announcements/models/announcement.dart';
import 'package:arise_application/core/services/local_cache.dart';

class AnnouncementsState {
  final bool loaded;
  final List<Announcement> items;
  final String? error;

  const AnnouncementsState({
    this.loaded = false,
    this.items = const [],
    this.error,
  });
}

/// Announcements, newest first. Reloads whenever one is posted, edited or
/// deleted. Posting is limited to teachers/admins by 06_announcements.sql.
class AnnouncementsCubit extends Cubit<AnnouncementsState> {
  AnnouncementsCubit() : super(const AnnouncementsState()) {
    _authSub = _sb.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        load();
      } else {
        _stopListening();
        if (!isClosed) emit(const AnnouncementsState());
      }
    });
  }

  final _sb = Supabase.instance.client;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;

  Future<void> load() async {
    if (_sb.auth.currentUser == null) return;
    _channel ??= _sb
        .channel('announcements-list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (_) => _fetch(),
        )
        .subscribe();
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final rows = await _sb
          .from('announcements')
          .select('*, profiles(username, profile_details(display_name))')
          .order('created_at', ascending: false)
          .limit(50);
      if (isClosed) return;
      await LocalCache.save('announcements', rows);
      emit(AnnouncementsState(
        loaded: true,
        items: [
          for (final r in rows)
            Announcement.fromRow(Map<String, dynamic>.from(r)),
        ],
      ));
    } catch (e) {
      // offline: show the last saved announcements
      final cached = await LocalCache.readRows('announcements');
      if (cached != null && !isClosed) {
        emit(AnnouncementsState(
          loaded: true,
          items: [for (final r in cached) Announcement.fromRow(r)],
        ));
        return;
      }
      if (!isClosed) {
        emit(AnnouncementsState(
            loaded: true, items: state.items, error: '$e'));
      }
    }
  }

  void _stopListening() {
    final c = _channel;
    _channel = null;
    if (c != null) _sb.removeChannel(c);
  }

  Future<void> post(String title, String body) async {
    await _sb
        .from('announcements')
        .insert({'title': title.trim(), 'body': body.trim()});
    await _fetch();
  }

  Future<void> update(String id, String title, String body) async {
    final rows = await _sb
        .from('announcements')
        .update({'title': title.trim(), 'body': body.trim()})
        .eq('id', id)
        .select();
    if (rows.isEmpty) throw 'You are not allowed to edit this announcement.';
    await _fetch();
  }

  Future<void> delete(String id) async {
    final rows =
        await _sb.from('announcements').delete().eq('id', id).select();
    if (rows.isEmpty) throw 'You are not allowed to delete this announcement.';
    await _fetch();
  }

  @override
  Future<void> close() {
    _stopListening();
    _authSub?.cancel();
    return super.close();
  }
}
