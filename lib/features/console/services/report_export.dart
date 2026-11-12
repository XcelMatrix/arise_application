import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/console/models/drill_record.dart';

/// Drill report as a PDF or a CSV (opens in Excel / Sheets), shared through
/// the phone's share sheet (save to Files, Drive, email, ...).
class ReportExport {
  static String _fileStem(DrillRecord r) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = r.started;
    return 'ARISE_drill_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';
  }

  static String _csvCell(Object? v) {
    final s = '${v ?? ''}';
    final needsQuotes = s.contains(',') || s.contains('"') || s.contains('\n');
    // stop spreadsheet formulas from running
    final safe = RegExp(r'^[=+\-@]').hasMatch(s) ? "'$s" : s;
    return needsQuotes || safe != s
        ? '"${safe.replaceAll('"', '""')}"'
        : safe;
  }

  static String csv(DrillRecord r) {
    final rows = <List<Object?>>[
      [
        'Drill started', 'Emergency', 'Evacuation time', 'Grade', 'Section',
        'Evacuation site', 'Report sent', 'Student', 'Status', 'Present',
        'Absent', 'Missing', 'Injured',
      ],
    ];
    final took = r.duration == null
        ? ''
        : DrillCubit.formatDurationWords(r.duration!);
    for (final rep in r.reports) {
      List<Object?> base(String student, String status) => [
            drillDate(r.started), rep.emergencyType, took, rep.grade,
            rep.section, rep.site, rep.submitted ? 'Yes' : 'No', student,
            status, rep.present, rep.absent, rep.missing, rep.injured,
          ];
      if (rep.students.isNotEmpty) {
        for (final s in rep.students) {
          rows.add(base(s.name, s.status?.label ?? 'Not marked'));
        }
      } else if (rep.notPresent.isNotEmpty) {
        for (final n in rep.notPresent) {
          rows.add(base(n.name, n.status.label));
        }
      } else {
        rows.add(base('', ''));
      }
    }
    // BOM so Excel reads names with accents correctly
    return '﻿${rows.map((row) => row.map(_csvCell).join(',')).join('\r\n')}\r\n';
  }

  static Future<pw.Document> pdf(DrillRecord r) async {
    final doc = pw.Document();
    final totals = [
      for (final s in AttendanceStatus.values) [s.label, '${r.total(s)}'],
    ];
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          pw.Text('ARISE Drill Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Started: ${drillDate(r.started)}'),
          pw.Text('Status: ${r.status}'),
          if (r.type.isNotEmpty) pw.Text('Emergency: ${r.type}'),
          if (r.duration != null)
            pw.Text('Evacuation time: ${DrillCubit.formatDurationWords(r.duration!)}'),
          pw.Text('Reports sent: ${r.reports.where((x) => x.submitted).length} of ${r.reports.length}'),
          pw.SizedBox(height: 14),
          pw.Text('Totals',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Status', 'Students'],
            data: totals,
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 14),
          pw.Text('Sections',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Section', 'Site', 'Present', 'Absent', 'Missing', 'Injured', 'Sent'],
            data: [
              for (final x in r.reports)
                [
                  x.consoleLabel, x.site, '${x.present}', '${x.absent}',
                  '${x.missing}', '${x.injured}', x.submitted ? 'Yes' : 'No',
                ],
            ],
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Missing and injured students',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if (r.reports.every((x) =>
              x.namesFor(AttendanceStatus.missing).isEmpty &&
              x.namesFor(AttendanceStatus.injured).isEmpty))
            pw.Text('None'),
          for (final x in r.reports)
            for (final s in [AttendanceStatus.missing, AttendanceStatus.injured])
              if (x.namesFor(s).isNotEmpty)
                pw.Text('${x.consoleLabel}  ${s.label}: ${x.namesFor(s).join(', ')}'),
        ],
      ),
    );
    return doc;
  }

  static Future<File> _write(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  static Future<void> sharePdf(DrillRecord r) async {
    final bytes = await (await pdf(r)).save();
    final f = await _write('${_fileStem(r)}.pdf', bytes);
    await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'application/pdf')],
        subject: 'ARISE drill report'));
  }

  static Future<void> shareCsv(DrillRecord r) async {
    final f = await _write('${_fileStem(r)}.csv', utf8.encode(csv(r)));
    await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'text/csv')],
        subject: 'ARISE drill report'));
  }
}
