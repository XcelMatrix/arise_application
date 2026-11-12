import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart' show gradeOptions;
import 'package:arise_application/core/theme/app_colors.dart';

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
                  value: grade,
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
