import 'package:flutter/material.dart';

/// Order here is the order of the dropdown.
enum AttendanceStatus {
  missing('missing', 'Missing', Color(0xFFB3261E)),
  injured('injured', 'Injured', Color(0xFFEF6C00)),
  present('present', 'Present', Color(0xFF2E7D32)),
  absent('absent', 'Absent', Color(0xFF757575));

  const AttendanceStatus(this.value, this.label, this.color);

  final String value; // what is stored in the database
  final String label;
  final Color color;

  static AttendanceStatus? parse(String? v) {
    for (final s in AttendanceStatus.values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

const List<String> emergencyTypes = [
  'Fire',
  'Earthquake',
  'Flood',
  'Typhoon',
  'Lockdown',
  'Other',
];

const List<String> gradeOptions = [
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026-11-07 20:28
String formatStamp(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

class Student {
  final String id;
  final String name;

  /// null = not marked yet
  final AttendanceStatus? status;
  final DateTime? createdAt;

  const Student({
    required this.id,
    required this.name,
    this.status,
    this.createdAt,
  });

  Student copyWith({AttendanceStatus? status, String? name}) => Student(
        id: id,
        name: name ?? this.name,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  factory Student.fromRow(Map<String, dynamic> row) => Student(
        id: row['id'] as String,
        name: row['name'] as String,
        status: AttendanceStatus.parse(row['status'] as String?),
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
      );
}

/// A student who was not present when the report was sent.
class NamedStatus {
  final String name;
  final AttendanceStatus status;

  const NamedStatus({required this.name, required this.status});
}

/// One attendance page: timestamp, grade, section, site, emergency type
/// and its students.
class AttendanceReport {
  final String id;
  final String ownerId;
  final DateTime eventTime;
  final String grade;
  final String section;
  final String site;
  final String emergencyType;
  final String? drillId;
  final bool submitted;
  final DateTime? submittedAt;

  // Counts stored on the server when the report was sent.
  final int totalCount;
  final int presentCount;
  final int absentCount;
  final int missingCount;
  final int injuredCount;

  /// Only filled for the signed-in user's own reports.
  final List<Student> students;

  /// Who was missing / injured / absent when the report was sent.
  /// This is what the timed console names.
  final List<NamedStatus> notPresent;

  const AttendanceReport({
    required this.id,
    required this.ownerId,
    required this.eventTime,
    required this.grade,
    required this.section,
    required this.site,
    required this.emergencyType,
    this.drillId,
    this.submitted = false,
    this.submittedAt,
    this.totalCount = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.missingCount = 0,
    this.injuredCount = 0,
    this.students = const [],
    this.notPresent = const [],
  });

  /// e.g. "11 - Polaris"
  String get label => '$grade - $section';

  /// e.g. "11-Polaris" (console style)
  String get consoleLabel => '$grade-$section';

  /// Names with this status. Live from the students when we have them,
  /// otherwise from what was saved when the report was sent.
  List<String> namesFor(AttendanceStatus s) {
    if (students.isNotEmpty) {
      return [for (final x in students) if (x.status == s) x.name];
    }
    return [for (final x in notPresent) if (x.status == s) x.name];
  }

  int get total => students.isNotEmpty ? students.length : totalCount;
  int get unmarked => students.where((s) => s.status == null).length;
  int get marked => students.length - unmarked;

  /// Live from the students when we have them, otherwise the server counts.
  int countFor(AttendanceStatus s) {
    if (students.isNotEmpty) {
      return students.where((x) => x.status == s).length;
    }
    switch (s) {
      case AttendanceStatus.present:
        return presentCount;
      case AttendanceStatus.absent:
        return absentCount;
      case AttendanceStatus.missing:
        return missingCount;
      case AttendanceStatus.injured:
        return injuredCount;
    }
  }

  int get present => countFor(AttendanceStatus.present);
  int get absent => countFor(AttendanceStatus.absent);
  int get missing => countFor(AttendanceStatus.missing);
  int get injured => countFor(AttendanceStatus.injured);

  AttendanceReport copyWith({List<Student>? students}) => AttendanceReport(
        id: id,
        ownerId: ownerId,
        eventTime: eventTime,
        grade: grade,
        section: section,
        site: site,
        emergencyType: emergencyType,
        drillId: drillId,
        submitted: submitted,
        submittedAt: submittedAt,
        totalCount: totalCount,
        presentCount: presentCount,
        absentCount: absentCount,
        missingCount: missingCount,
        injuredCount: injuredCount,
        students: students ?? this.students,
        notPresent: notPresent,
      );

  factory AttendanceReport.fromRow(Map<String, dynamic> row) {
    final nested = row['report_students'];
    final students = <Student>[];
    if (nested is List) {
      for (final e in nested) {
        students.add(Student.fromRow(Map<String, dynamic>.from(e as Map)));
      }
      students.sort((a, b) {
        if (a.createdAt == null || b.createdAt == null) return 0;
        return a.createdAt!.compareTo(b.createdAt!);
      });
    }
    int n(String key) => (row[key] as num?)?.toInt() ?? 0;

    final notPresent = <NamedStatus>[];
    final raw = row['not_present'];
    if (raw is List) {
      for (final e in raw) {
        if (e is! Map) continue;
        final status = AttendanceStatus.parse(e['status'] as String?);
        if (status == null) continue;
        notPresent.add(NamedStatus(name: e['name'] as String, status: status));
      }
    }

    return AttendanceReport(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      eventTime: DateTime.parse(row['event_time'] as String).toLocal(),
      grade: row['grade'] as String,
      section: row['section'] as String,
      site: row['evacuation_site'] as String,
      emergencyType: row['emergency_type'] as String,
      drillId: row['drill_id'] as String?,
      submitted: row['status'] == 'submitted',
      submittedAt: row['submitted_at'] != null
          ? DateTime.parse(row['submitted_at'] as String).toLocal()
          : null,
      totalCount: n('total_count'),
      presentCount: n('present_count'),
      absentCount: n('absent_count'),
      missingCount: n('missing_count'),
      injuredCount: n('injured_count'),
      students: students,
      notPresent: notPresent,
    );
  }
}

enum ConsoleLevel { info, success, warning, alert, system }

class ConsoleEntry {
  final DateTime time;
  final String message;
  final ConsoleLevel level;

  const ConsoleEntry({
    required this.time,
    required this.message,
    this.level = ConsoleLevel.info,
  });
}
