import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:arise_application/core/utils/time_format.dart';

/// Shared helpers for every export: write a PDF or CSV to a temporary file
/// and hand it to the phone's share sheet (save to Files, Drive, email...).
class ExportFiles {
  static String two(int n) => n.toString().padLeft(2, '0');

  static String date(DateTime t) => '${t.year}-${two(t.month)}-${two(t.day)}';

  static String dateTime(DateTime t) => '${date(t)} ${TimeFormat.clock(t)}';

  static String stem(String name, DateTime t) =>
      'ARISE_${name}_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';

  static String csvCell(Object? v) {
    final s = '${v ?? ''}';
    final needsQuotes = s.contains(',') || s.contains('"') || s.contains('\n');
    // stop spreadsheet formulas from running
    final safe = RegExp(r'^[=+\-@]').hasMatch(s) ? "'$s" : s;
    return needsQuotes || safe != s ? '"${safe.replaceAll('"', '""')}"' : safe;
  }

  /// UTF-8 with a BOM so Excel reads accents (ñ, ...) correctly.
  static String csv(List<List<Object?>> rows) =>
      '﻿${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';

  static Future<File> _write(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  static Future<void> shareCsv(
      String fileStem, List<List<Object?>> rows, String subject) async {
    final f = await _write('$fileStem.csv', utf8.encode(csv(rows)));
    await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'text/csv')], subject: subject));
  }

  static Future<void> sharePdf(
      String fileStem, pw.Document doc, String subject) async {
    final f = await _write('$fileStem.pdf', await doc.save());
    await SharePlus.instance.share(ShareParams(
        files: [XFile(f.path, mimeType: 'application/pdf')], subject: subject));
  }

  // ---- small PDF building blocks (styled like the app: dark cyan) ----
  static const cyan = PdfColor.fromInt(0xFF3C6E87);
  static const cyanLight = PdfColor.fromInt(0xFFE4F2F9);

  /// Dark cyan banner with the ARISE name and the document title.
  static pw.Widget h1(String t) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: pw.BoxDecoration(
          color: cyan,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ARISE',
                style: pw.TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: pw.FontWeight.bold,
                    color: cyanLight)),
            pw.SizedBox(height: 4),
            pw.Text(t,
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ],
        ),
      );

  /// Section heading with a dark cyan bar beside it.
  static pw.Widget h2(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 16, color: cyan),
          pw.SizedBox(width: 8),
          pw.Text(t,
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: cyan)),
        ]),
      );

  static pw.Widget table(List<String> headers, List<List<String>> data) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        cellAlignment: pw.Alignment.centerLeft,
        headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9.5,
            color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: cyan),
        cellStyle: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey900),
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        border: pw.TableBorder(
          horizontalInside: const pw.BorderSide(color: cyanLight, width: 0.8),
          bottom: const pw.BorderSide(color: cyan, width: 1),
        ),
        oddRowDecoration: const pw.BoxDecoration(color: cyanLight),
      );

  static pw.Document document(List<pw.Widget> Function(pw.Context) build) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: cyan, width: 1))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ARISE',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: cyan)),
            pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: cyan)),
          ],
        ),
      ),
      build: build,
    ));
    return doc;
  }
}
