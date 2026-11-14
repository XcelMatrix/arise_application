import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart' show gradeOptions;
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/attendance/services/student_csv.dart';

/// A teacher's saved class lists: name, grade, section and student names.
/// Import one into any attendance report instead of typing names again.
class ClassListsPage extends StatelessWidget {
  const ClassListsPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() =>
      MaterialPageRoute(builder: (context) => const ClassListsPage());

  Future<void> _edit(BuildContext context, [Map<String, dynamic>? row]) async {
    final cubit = context.read<ClassListsCubit>();
    final name = TextEditingController(text: row?['name'] ?? '');
    final section = TextEditingController(text: row?['section'] ?? '');
    final students = TextEditingController(
        text: ((row?['students'] as List?) ?? const []).join('\n'));
    String? grade = row?['grade'] as String?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(row == null ? 'New class list' : 'Edit class list'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 80,
                  decoration: InputDecoration(labelText: tr(ctx, 'List name')),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(grade),
                  initialValue: grade,
                  decoration: InputDecoration(labelText: tr(ctx, 'Grade')),
                  items: [
                    for (final g in gradeOptions)
                      DropdownMenuItem(value: g, child: Text.verbatim(g)),
                  ],
                  onChanged: (v) => setState(() => grade = v),
                ),
                TextField(
                  controller: section,
                  decoration: InputDecoration(labelText: tr(ctx, 'Section')),
                ),
                TextField(
                  controller: students,
                  minLines: 5,
                  maxLines: 10,
                  decoration: InputDecoration(
                      labelText: tr(ctx, 'Students (one name per line)')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final values = {
      'name': name.text.trim(),
      'grade': grade,
      'section': section.text.trim().isEmpty ? null : section.text.trim(),
      'students': [
        for (final l in students.text.split('\n'))
          if (l.trim().isNotEmpty) l.trim(),
      ],
    };
    name.dispose();
    section.dispose();
    students.dispose();
    if (ok != true || (values['name'] as String).isEmpty) return;
    try {
      row == null
          ? await cubit.add(values)
          : await cubit.edit(row['id'] as String, values);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text.verbatim('$e')));
      }
    }
  }

  /// Fill class lists from a spreadsheet saved as CSV.
  Future<void> _import(BuildContext context) async {
    final cubit = context.read<ClassListsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    void toast(String m) =>
        messenger.showSnackBar(SnackBar(content: Text.verbatim(m)));

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import students from a spreadsheet'),
        content: const SingleChildScrollView(
          child: Text(
              'In Excel or Google Sheets, make columns named Name, Grade and Section (Grade and Section are optional), then save the file as CSV.\n\nExample:\nName,Grade,Section\nJuan Dela Cruz,7,Rizal\nMaria Santos,7,Rizal\n\nEach grade and section becomes its own class list. Names already in a list are not added twice.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose file')),
        ],
      ),
    );
    if (go != true) return;

    List<ImportedClass> found;
    try {
      final dynamic res = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['csv', 'txt']);
      if (res == null) return;
      final List<PlatformFile> list = res is List
          ? res.cast<PlatformFile>()
          : List<PlatformFile>.from(res.files);
      final path = list.isEmpty ? null : list.first.path;
      if (path == null) return;
      final text = utf8.decode(await File(path).readAsBytes(), allowMalformed: true);
      found = StudentCsv.parse(text);
    } catch (e) {
      toast('$e');
      return;
    }
    if (found.isEmpty) {
      toast(Tr.t('No students found in that file.'));
      return;
    }

    // match with the lists this teacher already has (same grade + section)
    final existing = cubit.state.rows;
    Map<String, dynamic>? match(ImportedClass c) {
      for (final r in existing) {
        final g = '${r['grade'] ?? ''}'.trim().toLowerCase();
        final s = '${r['section'] ?? ''}'.trim().toLowerCase();
        if (g == (c.grade ?? '').toLowerCase() &&
            s == (c.section ?? '').toLowerCase() &&
            (c.grade != null || c.section != null)) {
          return r;
        }
      }
      return null;
    }

    if (!context.mounted) return;
    final total = found.fold<int>(0, (n, c) => n + c.students.length);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text.verbatim('${tr(ctx, 'Import')} $total ${tr(ctx, 'students')}?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in found)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.verbatim(
                      '• ${match(c) != null ? tr(ctx, 'Add to') : tr(ctx, 'New list')}: '
                      '${match(c)?['name'] ?? c.title} (${c.students.length})'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (ok != true) return;

    var added = 0;
    try {
      for (final c in found) {
        final m = match(c);
        if (m == null) {
          await cubit.add({
            'name': c.title,
            'grade': c.grade,
            'section': c.section,
            'students': c.students,
          });
          added += c.students.length;
        } else {
          final have = {
            for (final s in (m['students'] as List).cast<String>()) s.toLowerCase(),
          };
          final fresh = [for (final n in c.students) if (!have.contains(n.toLowerCase())) n];
          if (fresh.isEmpty) continue;
          await cubit.edit(m['id'] as String, {
            'students': [...(m['students'] as List).cast<String>(), ...fresh],
          });
          added += fresh.length;
        }
      }
      toast('${tr(context, 'Imported')} $added ${tr(context, 'students')}.');
    } catch (e) {
      toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ClassListsCubit>().state;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Class lists'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: tr(context, 'Import students from a spreadsheet'),
            icon: const Icon(Icons.upload_file),
            onPressed: () => _import(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
      body: !s.loaded
          ? const FlashingLogo()
          : s.rows.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                      'No class lists yet. Create one here, or save a list from an attendance report.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    for (final r in s.rows)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.groups, color: _blue),
                          title: Text.verbatim(r['name'] as String,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text(context),
                                  fontFamily: 'Geist')),
                          subtitle: Text.verbatim(
                              '${(r['students'] as List).length} ${tr(context, 'students')}'),
                          onTap: () => _edit(context, r),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final cubit = context.read<ClassListsCubit>();
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete this class list?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (ok == true) await cubit.remove(r['id'] as String);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
