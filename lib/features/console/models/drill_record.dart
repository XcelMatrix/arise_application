import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';

String drillDate(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${DrillCubit.formatClock(t)}';

class DrillRecord {
  final String id;
  final String status;
  final DateTime started;
  final DateTime? ended;
  final List<AttendanceReport> reports;
  DrillRecord(this.id, this.status, this.started, this.ended, this.reports);

  factory DrillRecord.fromRow(Map<String, dynamic> r) {
    final reps = [
      for (final e in (r['attendance_reports'] as List? ?? const []))
        AttendanceReport.fromRow(Map<String, dynamic>.from(e as Map)),
    ]..sort((a, b) => a.label.compareTo(b.label));
    return DrillRecord(
      r['id'] as String,
      r['status'] as String,
      DateTime.parse(r['started_at'] as String).toLocal(),
      r['ended_at'] != null
          ? DateTime.parse(r['ended_at'] as String).toLocal()
          : null,
      reps,
    );
  }

  Duration? get duration => ended?.difference(started);
  String get type => reports.isEmpty ? '' : reports.first.emergencyType;
  int total(AttendanceStatus s) =>
      reports.where((r) => r.submitted).fold(0, (a, r) => a + r.countFor(s));

  /// plain-text report for copying / sharing
  String asText() {
    final b = StringBuffer()
      ..writeln('ARISE drill report')
      ..writeln('Started: ${drillDate(started)}')
      ..writeln('Status: $status');
    if (type.isNotEmpty) b.writeln('Emergency: $type');
    if (duration != null) {
      b.writeln('Evacuation time: ${DrillCubit.formatDurationWords(duration!)}');
    }
    b.writeln('Reports sent: ${reports.where((r) => r.submitted).length}/${reports.length}');
    for (final s in AttendanceStatus.values) {
      b.writeln('${s.label}: ${total(s)}');
    }
    b.writeln();
    for (final r in reports) {
      b.writeln('${r.consoleLabel} (${r.site}) - '
          'Present ${r.present}, Absent ${r.absent}, Missing ${r.missing}, Injured ${r.injured}'
          '${r.submitted ? '' : ' - NOT SENT'}');
      for (final s in [AttendanceStatus.missing, AttendanceStatus.injured]) {
        final n = r.namesFor(s);
        if (n.isNotEmpty) b.writeln('  ${s.label}: ${n.join(', ')}');
      }
    }
    return b.toString();
  }
}

