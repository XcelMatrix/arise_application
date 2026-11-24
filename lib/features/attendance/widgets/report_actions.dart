import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/widgets/form_style.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/attendance/widgets/report_form_dialog.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';

/// The actions of an attendance's three-dot menu, usable straight from the
/// attendance list (everything except "Mark all present").
class ReportActions {
  static void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static Future<void> _guard(BuildContext context, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      _toast(context, DrillCubit.describe(e));
    }
  }

  static Future<void> edit(BuildContext context, AttendanceReport report) async {
    final cubit = context.read<DrillCubit>();
    final input = await showDialog<NewReportInput>(
      context: context,
      builder: (_) => ReportFormDialog(initial: report),
    );
    if (input == null || !context.mounted) return;
    await _guard(
        context,
        () => cubit.updateReport(
              report.id,
              grade: input.grade,
              section: input.section,
              site: input.site,
              emergencyType: input.emergencyType,
              eventTime: input.eventTime,
            ));
  }

  static Future<void> delete(BuildContext context, AttendanceReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${report.label}?'),
        content: const Text('This attendance and its students will be removed.'),
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
    if (ok != true || !context.mounted) return;
    final cubit = context.read<DrillCubit>();
    await _guard(context, () => cubit.deleteReport(report.id));
  }

  static Future<void> importList(BuildContext context, AttendanceReport report) async {
    final lists = context.read<ClassListsCubit>().state.rows;
    final cubit = context.read<DrillCubit>();
    List<String> signedUp = const [];
    try {
      final rows = await Supabase.instance.client.rpc('class_roster',
          params: {'p_grade': report.grade, 'p_section': report.section});
      signedUp = [for (final r in rows as List) '${(r as Map)['name']}'];
    } catch (_) {
      // offline or not available: the saved lists still work
    }
    if (!context.mounted) return;
    if (lists.isEmpty && signedUp.isEmpty) {
      _toast(context, Tr.t('You have no saved class lists yet.'));
      return;
    }
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add from class list'),
        children: [
          if (signedUp.isNotEmpty)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, signedUp),
              child: Text.verbatim(
                  '${tr(ctx, 'Students who signed up')}: ${report.grade}-${report.section}  (${signedUp.length})'),
            ),
          for (final l in lists)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(ctx, (l['students'] as List).cast<String>()),
              child: Text.verbatim(
                  '${l['name']}  (${(l['students'] as List).length})'),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final have = {for (final st in report.students) st.name.toLowerCase()};
    var added = 0;
    await _guard(context, () async {
      for (final n in picked) {
        if (have.add(n.toLowerCase())) {
          await cubit.addStudent(report.id, n);
          added++;
        }
      }
    });
    _toast(context, 'Added $added student(s).');
  }

  static Future<void> saveAsList(BuildContext context, AttendanceReport report) async {
    final c = TextEditingController(text: report.label);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as class list'),
        content: TextField(
          controller: c,
          maxLength: 80,
          decoration: InputDecoration(labelText: tr(ctx, 'List name')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    disposeLater([c]);
    if (name == null || name.isEmpty || !context.mounted) return;
    final lists = context.read<ClassListsCubit>();
    await _guard(
        context,
        () => lists.add({
              'name': name,
              'grade': report.grade,
              'section': report.section,
              'students': [for (final st in report.students) st.name],
            }));
    _toast(context, Tr.t('Class list saved.'));
  }
}
