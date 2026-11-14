/// Reads a student spreadsheet saved as CSV (from Excel or Google Sheets:
/// File > Save as / Download > CSV).
///
/// Columns, in any order, found by their header: Name (or First name + Last
/// name), Grade, Section. Without a header row the columns are taken as
/// name, grade, section. Commas, semicolons and tabs are all understood.
class ImportedClass {
  ImportedClass(this.grade, this.section);
  final String? grade;
  final String? section;
  final List<String> students = [];

  /// "7 - Rizal", "Rizal", "Grade 7" or "Imported students"
  String get title {
    final g = grade, s = section;
    if (g != null && s != null && s.isNotEmpty) return '$g - $s';
    if (s != null && s.isNotEmpty) return s;
    if (g != null) return 'Grade $g';
    return 'Imported students';
  }
}

class StudentCsv {
  /// Split CSV text into rows of cells (handles "quoted, cells" and "" quotes).
  static List<List<String>> rows(String text) {
    var t = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (t.startsWith('﻿')) t = t.substring(1);
    final firstLine =
        t.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    var delim = ',';
    var best = -1;
    for (final d in [',', ';', '\t']) {
      final n = d.allMatches(firstLine).length;
      if (n > best) {
        best = n;
        delim = d;
      }
    }

    final out = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < t.length; i++) {
      final c = t[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < t.length && t[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == delim) {
        row.add(cell.toString());
        cell.clear();
      } else if (c == '\n') {
        row.add(cell.toString());
        cell.clear();
        out.add(row);
        row = <String>[];
      } else {
        cell.write(c);
      }
    }
    row.add(cell.toString());
    out.add(row);
    return out;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  static String? _grade(String s) {
    final m = RegExp(r'(\d{1,2})').firstMatch(s);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    return (n >= 1 && n <= 12) ? '$n' : null;
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Students grouped by grade + section, names without duplicates.
  static List<ImportedClass> parse(String text) {
    final all = rows(text)
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList();
    if (all.isEmpty) return [];

    int? nameI, firstI, lastI, gradeI, sectionI;
    final head = all.first.map(_norm).toList();
    for (var i = 0; i < head.length; i++) {
      final h = head[i];
      if (const [
        'name', 'studentname', 'student', 'fullname', 'pangalan', 'learner',
        'learnername'
      ].contains(h)) {
        nameI ??= i;
      } else if (const ['firstname', 'givenname', 'given'].contains(h)) {
        firstI ??= i;
      } else if (const ['lastname', 'surname', 'familyname'].contains(h)) {
        lastI ??= i;
      } else if (const [
        'grade', 'gradelevel', 'year', 'yearlevel', 'level', 'baitang'
      ].contains(h)) {
        gradeI ??= i;
      } else if (const ['section', 'seksyon', 'class', 'classsection']
          .contains(h)) {
        sectionI ??= i;
      }
    }
    final hasHeader = nameI != null || (firstI != null && lastI != null);
    var data = all;
    if (hasHeader) {
      data = all.sublist(1);
    } else {
      nameI = 0;
      gradeI = all.first.length > 1 ? 1 : null;
      sectionI = all.first.length > 2 ? 2 : null;
    }

    String cellAt(List<String> r, int? i) =>
        (i == null || i >= r.length) ? '' : r[i];

    final groups = <String, ImportedClass>{};
    final seen = <String, Set<String>>{};
    for (final r in data) {
      final name = nameI != null
          ? _clean(cellAt(r, nameI))
          : _clean('${cellAt(r, lastI)}, ${cellAt(r, firstI)}');
      if (name == ',' || name.isEmpty) continue;
      final grade = _grade(cellAt(r, gradeI));
      final section = _clean(cellAt(r, sectionI));
      final key = '${grade ?? ''}|${section.toLowerCase()}';
      final g = groups.putIfAbsent(
          key, () => ImportedClass(grade, section.isEmpty ? null : section));
      if (seen.putIfAbsent(key, () => <String>{}).add(name.toLowerCase())) {
        g.students.add(name);
      }
    }
    return groups.values.toList();
  }
}
