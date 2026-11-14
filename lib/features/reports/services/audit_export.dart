import 'package:pdf/widgets.dart' as pw;
import 'package:arise_application/features/admin/widgets/audit_text.dart';
import 'package:arise_application/features/console/cubit/audit_cubit.dart';
import 'package:arise_application/features/reports/services/export_files.dart';
import 'package:arise_application/translations/translation.dart';

/// Audit log as CSV / PDF, in the language picked in Settings.
class AuditExport {
  static List<List<Object?>> rows(
          List<AuditEntry> entries, List<Map<String, dynamic>> alerts) =>
      [
        [Tr.t('Date and time'), Tr.t('Who'), Tr.t('Action'), Tr.t('Details')],
        for (final e in entries)
          [
            ExportFiles.dateTime(e.time),
            e.actor,
            AuditText.action(e),
            AuditText.detail(e, alerts) ?? '',
          ],
      ];

  static pw.Document pdf(
      List<AuditEntry> entries, List<Map<String, dynamic>> alerts) {
    final r = rows(entries, alerts);
    return ExportFiles.document((ctx) => [
          ExportFiles.h1(Tr.t('Audit log')),
          pw.SizedBox(height: 4),
          pw.Text('${Tr.t('Created')}: ${ExportFiles.dateTime(DateTime.now())}'),
          pw.Text('${Tr.t('Entries')}: ${entries.length}'),
          pw.SizedBox(height: 10),
          ExportFiles.table(
            [for (final c in r.first) '$c'],
            [for (final row in r.skip(1)) [for (final c in row) '$c']],
          ),
        ]);
  }

  static Future<void> sharePdf(
          List<AuditEntry> e, List<Map<String, dynamic>> alerts) =>
      ExportFiles.sharePdf(ExportFiles.stem('audit_log', DateTime.now()),
          pdf(e, alerts), 'ARISE audit log');

  static Future<void> shareCsv(
          List<AuditEntry> e, List<Map<String, dynamic>> alerts) =>
      ExportFiles.shareCsv(ExportFiles.stem('audit_log', DateTime.now()),
          rows(e, alerts), 'ARISE audit log');
}
