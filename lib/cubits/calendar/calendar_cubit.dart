import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/models/calendar_event.dart';

class CalendarState {
  final bool loaded;
  final List<CalendarEvent> events;
  final String? error;

  const CalendarState({
    this.loaded = false,
    this.events = const [],
    this.error,
  });

  /// date-only key -> that day's events
  List<CalendarEvent> on(DateTime day) => events
      .where((e) =>
          e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day)
      .toList();
}

/// Reads the shared calendar live. Writing is allowed only for accounts the
/// database says may edit (see 05_calendar.sql); the page hides the controls
/// from everyone else.
class CalendarCubit extends Cubit<CalendarState> {
  CalendarCubit() : super(const CalendarState()) {
    _authSub = _sb.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        load();
      } else {
        _sub?.cancel();
        _sub = null;
        if (!isClosed) emit(const CalendarState());
      }
    });
  }

  final _sb = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  StreamSubscription<AuthState>? _authSub;

  void load() {
    if (_sb.auth.currentUser == null) return;
    _sub?.cancel();
    _sub = _sb
        .from('calendar_events')
        .stream(primaryKey: ['id'])
        .order('event_date')
        .listen((rows) {
      final events = [
        for (final r in rows) CalendarEvent.fromRow(Map<String, dynamic>.from(r)),
      ]..sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.sortMinutes.compareTo(b.sortMinutes);
        });
      if (!isClosed) emit(CalendarState(loaded: true, events: events));
    }, onError: (e) {
      if (!isClosed) {
        emit(CalendarState(loaded: true, events: state.events, error: '$e'));
      }
    });
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String? _timeStr(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}:00';

  Map<String, dynamic> _row(
          String title, String? details, DateTime date, TimeOfDay? time) =>
      {
        'title': title.trim(),
        'details': (details == null || details.trim().isEmpty)
            ? null
            : details.trim(),
        'event_date': _dateStr(date),
        'start_time': _timeStr(time),
      };

  Future<void> add(String title, String? details, DateTime date,
      TimeOfDay? time) async {
    await _sb.from('calendar_events').insert(_row(title, details, date, time));
  }

  Future<void> update(String id, String title, String? details, DateTime date,
      TimeOfDay? time) async {
    final rows = await _sb
        .from('calendar_events')
        .update(_row(title, details, date, time))
        .eq('id', id)
        .select();
    if (rows.isEmpty) throw 'You are not allowed to edit events.';
  }

  Future<void> delete(String id) async {
    final rows =
        await _sb.from('calendar_events').delete().eq('id', id).select();
    if (rows.isEmpty) throw 'You are not allowed to delete events.';
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _authSub?.cancel();
    return super.close();
  }
}
