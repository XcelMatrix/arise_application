import 'package:flutter/material.dart' show TimeOfDay;

/// One important date on the school calendar.
class CalendarEvent {
  final String id;
  final String title;
  final String? details;
  final DateTime date; // date only (local, midnight)
  final TimeOfDay? time;

  /// Set when this is a scheduled drill (the emergency type, e.g. Fire).
  final String? drillType;

  bool get isDrill => drillType != null;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.details,
    this.time,
    this.drillType,
  });

  factory CalendarEvent.fromRow(Map<String, dynamic> row) {
    // event_date: "2026-11-09", start_time: "14:30:00"
    final d = (row['event_date'] as String).split('-');
    TimeOfDay? time;
    final t = row['start_time'] as String?;
    if (t != null && t.length >= 5) {
      time = TimeOfDay(
        hour: int.parse(t.substring(0, 2)),
        minute: int.parse(t.substring(3, 5)),
      );
    }
    final details = row['details'] as String?;
    return CalendarEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      details: (details == null || details.trim().isEmpty) ? null : details,
      date: DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2])),
      time: time,
      drillType: row['kind'] == 'drill'
          ? (row['drill_type'] as String? ?? 'Other')
          : null,
    );
  }

  /// minutes since midnight, for sorting (no time = start of day)
  int get sortMinutes => time == null ? -1 : time!.hour * 60 + time!.minute;
}
