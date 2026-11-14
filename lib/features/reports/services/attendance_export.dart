import 'package:pdf/widgets.dart' as pw;
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/console/models/drill_record.dart';
import 'package:arise_application/features/reports/services/export_files.dart';
import 'package:arise_application/translations/translation.dart';

/// Totals over a group of attendance reports.
class AttendanceTotals {
  AttendanceTotals(Iterable<AttendanceReport> reports) {
    for (final r in reports) {
      count++;
      if (r.submitted) sent++;
      total += r.total;
      present += r.present;
      absent += r.absent;
      missing += r.missing;
      injured += r.injured;
    }
  }
  int count = 0, sent = 0, total = 0;
  int present = 0, absent = 0, missing = 0, injured = 0;
}

/// Attendance and drill summaries as CSV / PDF, in the language picked in
/// Settings. (A single drill's full report is exported from Drill history.)
class AttendanceExport {
  static String _status(AttendanceStatus s) => Tr.t(s.label);
  static String _yes(bool v) => Tr.t(v ? 'Yes' : 'No');

  // ----------------------------------------------------- attendance summary

  static List<List<Object?>> attendanceCsv(List<AttendanceReport> reports,
      {required bool names}) {
    final head = <Object?>[
      Tr.t('Date'), Tr.t('Grade'), Tr.t('Section'), Tr.t('Emergency'),
      Tr.t('Evacuation site'), Tr.t('Students'), _status(AttendanceStatus.present),
      _status(AttendanceStatus.absent), _status(AttendanceStatus.missing),
      _status(AttendanceStatus.injured), Tr.t('Report sent'),
      if (names) Tr.t('Missing and injured students'),
    ];
    return [
      head,
      for (final r in reports)
        [
          ExportFiles.dateTime(r.eventTime), r.grade, r.section,
          Tr.t(r.emergencyType), r.site, r.total, r.present, r.absent,
          r.missing, r.injured, _yes(r.submitted),
          if (names)
            [
              for (final s in [AttendanceStatus.missing, AttendanceStatus.injured])
                if (r.namesFor(s).isNotEmpty)
                  '${_status(s)}: ${r.namesFor(s).join('; ')}',
            ].join(' | '),
        ],
    ];
  }

  static pw.Document attendancePdf(List<AttendanceReport> reports,
      {required String period, required bool names}) {
    final all = AttendanceTotals(reports);
    // totals for each grade and section
    final groups = <String, List<AttendanceReport>>{};
    for (final r in reports) {
      groups.putIfAbsent(r.consoleLabel, () => []).add(r);
    }
    final keys = groups.keys.toList()..sort();

    return ExportFiles.document((ctx) => [
          ExportFiles.h1(Tr.t('Attendance summary')),
          pw.SizedBox(height: 4),
          pw.Text('${Tr.t('Period')}: $period'),
          pw.Text('${Tr.t('Created')}: ${ExportFiles.dateTime(DateTime.now())}'),
          pw.Text(
              '${Tr.t('Reports')}: ${all.count}   ${Tr.t('Reports sent')}: ${all.sent}'),
          ExportFiles.h2(Tr.t('Totals')),
          ExportFiles.table([
            Tr.t('Students'), _status(AttendanceStatus.present),
            _status(AttendanceStatus.absent), _status(AttendanceStatus.missing),
            _status(AttendanceStatus.injured),
          ], [
            ['${all.total}', '${all.present}', '${all.absent}', '${all.missing}', '${all.injured}'],
          ]),
          ExportFiles.h2(Tr.t('By section')),
          ExportFiles.table([
            Tr.t('Section'), Tr.t('Reports'), Tr.t('Students'),
            _status(AttendanceStatus.present), _status(AttendanceStatus.absent),
            _status(AttendanceStatus.missing), _status(AttendanceStatus.injured),
          ], [
            for (final k in keys)
              () {
                final t = AttendanceTotals(groups[k]!);
                return [k, '${t.count}', '${t.total}', '${t.present}', '${t.absent}', '${t.missing}', '${t.injured}'];
              }(),
          ]),
          ExportFiles.h2(Tr.t('All reports')),
          ExportFiles.table([
            Tr.t('Date'), Tr.t('Section'), Tr.t('Emergency'), Tr.t('Evacuation site'),
            _status(AttendanceStatus.present), _status(AttendanceStatus.absent),
            _status(AttendanceStatus.missing), _status(AttendanceStatus.injured),
            Tr.t('Report sent'),
          ], [
            for (final r in reports)
              [
                ExportFiles.dateTime(r.eventTime), r.consoleLabel,
                Tr.t(r.emergencyType), r.site, '${r.present}', '${r.absent}',
                '${r.missing}', '${r.injured}', _yes(r.submitted),
              ],
          ]),
          if (names) ...[
            ExportFiles.h2(Tr.t('Missing and injured students')),
            () {
              final lines = <pw.Widget>[];
              for (final r in reports) {
                for (final s in [AttendanceStatus.missing, AttendanceStatus.injured]) {
                  final n = r.namesFor(s);
                  if (n.isNotEmpty) {
                    lines.add(pw.Text(
                        '${ExportFiles.date(r.eventTime)}  ${r.consoleLabel}  ${_status(s)}: ${n.join(', ')}'));
                  }
                }
              }
              return lines.isEmpty
                  ? pw.Text(Tr.t('None'))
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: lines);
            }(),
          ],
        ]);
  }

  // ------------------------------------------------------------ drill summary

  static List<List<Object?>> drillsCsv(List<DrillRecord> drills) => [
        [
          Tr.t('Drill started'), Tr.t('Emergency'), Tr.t('Status'),
          Tr.t('Evacuation time'), Tr.t('Reports sent'), Tr.t('Students'),
          _status(AttendanceStatus.present), _status(AttendanceStatus.absent),
          _status(AttendanceStatus.missing), _status(AttendanceStatus.injured),
        ],
        for (final d in drills)
          [
            drillDate(d.started), Tr.t(d.type), Tr.t(_drillStatus(d.status)),
            d.duration == null ? '' : DrillCubit.formatDurationWords(d.duration!),
            '${d.reports.where((r) => r.submitted).length}/${d.reports.length}',
            d.reports.where((r) => r.submitted).fold<int>(0, (a, r) => a + r.total),
            d.total(AttendanceStatus.present), d.total(AttendanceStatus.absent),
            d.total(AttendanceStatus.missing), d.total(AttendanceStatus.injured),
          ],
      ];

  static String _drillStatus(String s) =>
      s == 'complete' ? 'Complete' : s == 'cancelled' ? 'Cancelled' : s;

  static pw.Document drillsPdf(List<DrillRecord> drills, {required String period}) {
    final done = drills.where((d) => d.status == 'complete').toList();
    final times = [for (final d in done) if (d.duration != null) d.duration!];
    final avg = times.isEmpty
        ? null
        : Duration(
            seconds: times.fold<int>(0, (a, d) => a + d.inSeconds) ~/ times.length);
    final best = times.isEmpty ? null : (times.toList()..sort()).first;

    return ExportFiles.document((ctx) => [
          ExportFiles.h1(Tr.t('Drill summary')),
          pw.SizedBox(height: 4),
          pw.Text('${Tr.t('Period')}: $period'),
          pw.Text('${Tr.t('Created')}: ${ExportFiles.dateTime(DateTime.now())}'),
          pw.Text('${Tr.t('Drills')}: ${drills.length}   ${Tr.t('Complete')}: ${done.length}'),
          if (avg != null)
            pw.Text('${Tr.t('Average evacuation time')}: ${DrillCubit.formatDurationWords(avg)}'),
          if (best != null)
            pw.Text('${Tr.t('Fastest evacuation')}: ${DrillCubit.formatDurationWords(best)}'),
          ExportFiles.h2(Tr.t('All drills')),
          ExportFiles.table([
            Tr.t('Drill started'), Tr.t('Emergency'), Tr.t('Status'),
            Tr.t('Evacuation time'), Tr.t('Reports sent'),
            _status(AttendanceStatus.present), _status(AttendanceStatus.absent),
            _status(AttendanceStatus.missing), _status(AttendanceStatus.injured),
          ], [
            for (final d in drills)
              [
                drillDate(d.started), Tr.t(d.type), Tr.t(_drillStatus(d.status)),
                d.duration == null ? '-' : DrillCubit.formatDurationWords(d.duration!),
                '${d.reports.where((r) => r.submitted).length}/${d.reports.length}',
                '${d.total(AttendanceStatus.present)}', '${d.total(AttendanceStatus.absent)}',
                '${d.total(AttendanceStatus.missing)}', '${d.total(AttendanceStatus.injured)}',
              ],
          ]),
        ]);
  }
}
