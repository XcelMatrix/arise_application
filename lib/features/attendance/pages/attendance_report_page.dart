import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/widgets/access_gate.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/features/attendance/widgets/report_form_dialog.dart';

/// One attendance report. Grade, section, site, emergency type and
/// timestamp were set when it was created, so students only need a name.
class AttendanceReportPage extends StatefulWidget {
  const AttendanceReportPage({super.key, required this.reportId});

  final String reportId;

  static Route<void> route(String reportId) {
    return MaterialPageRoute(
        builder: (context) => AttendanceReportPage(reportId: reportId));
  }

  @override
  State<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  static const _blue = Color(0xFF3C6E87);
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      _toast(DrillCubit.describe(e));
    }
  }

  /// Add everyone from one of the teacher's saved class lists, or the
  /// students who signed up for this report's grade and section.
  Future<void> _importList(AttendanceReport report) async {
    final lists = context.read<ClassListsCubit>().state.rows;
    List<String> signedUp = const [];
    try {
      final rows = await Supabase.instance.client.rpc('class_roster',
          params: {'p_grade': report.grade, 'p_section': report.section});
      signedUp = [for (final r in rows as List) '${(r as Map)['name']}'];
    } catch (_) {
      // offline or not available: the saved lists still work
    }
    if (!mounted) return;
    if (lists.isEmpty && signedUp.isEmpty) {
      _toast('You have no saved class lists yet.');
      return;
    }
    final cubit = context.read<DrillCubit>();
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
    if (picked == null) return;
    final have = {for (final st in report.students) st.name.toLowerCase()};
    var added = 0;
    await _guard(() async {
      for (final n in picked) {
        if (have.add(n.toLowerCase())) {
          await cubit.addStudent(widget.reportId, n);
          added++;
        }
      }
    });
    _toast('Added $added student(s).');
  }

  /// Save this report's students as a reusable class list.
  Future<void> _saveAsList(AttendanceReport report) async {
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
    c.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final lists = context.read<ClassListsCubit>();
    await _guard(() => lists.add({
          'name': name,
          'grade': report.grade,
          'section': report.section,
          'students': [for (final st in report.students) st.name],
        }));
    _toast('Class list saved.');
  }

  Future<void> _addStudent() async {
    final text = _nameController.text;
    if (text.trim().isEmpty) return;
    final cubit = context.read<DrillCubit>();
    _nameController.clear();
    _nameFocus.requestFocus(); // keep typing the next name
    await _guard(() => cubit.addStudent(widget.reportId, text));
  }

  Future<void> _setStatus(String studentId, AttendanceStatus status) async {
    final cubit = context.read<DrillCubit>();
    await _guard(() async {
      final sent = await cubit.setStatus(widget.reportId, studentId, status);
      if (sent) _toast('All set. Report sent to the Console.');
    });
  }

  Future<void> _markAllPresent() async {
    final cubit = context.read<DrillCubit>();
    await _guard(() async {
      final sent =
          await cubit.setAllStatus(widget.reportId, AttendanceStatus.present);
      if (sent) _toast('All set. Report sent to the Console.');
    });
  }

  Future<void> _edit(AttendanceReport report) async {
    final cubit = context.read<DrillCubit>();
    final input = await showDialog<NewReportInput>(
      context: context,
      builder: (_) => ReportFormDialog(initial: report),
    );
    if (input == null || !mounted) return;
    await _guard(() => cubit.updateReport(
          report.id,
          grade: input.grade,
          section: input.section,
          site: input.site,
          emergencyType: input.emergencyType,
          eventTime: input.eventTime,
        ));
  }

  Future<void> _rename(Student student) async {
    final cubit = context.read<DrillCubit>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: student.name),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    await _guard(
        () => cubit.renameStudent(widget.reportId, student.id, name));
  }

  Future<void> _delete(AttendanceReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${report.label}?'),
        content: const Text(
            'This attendance and its students will be removed.'),
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
    if (ok != true || !mounted) return;

    final cubit = context.read<DrillCubit>();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    try {
      await cubit.deleteReport(report.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(DrillCubit.describe(e))));
    }
  }

  @override
  Widget build(BuildContext context) => AccessGate(
        feature: Feature.attendance,
        child: Builder(builder: _page),
      );

  Widget _page(BuildContext context) {
    return BlocBuilder<DrillCubit, DrillState>(
      builder: (context, state) {
        final matches = state.mine.where((r) => r.id == widget.reportId);
        if (matches.isEmpty) {
          return const Scaffold(
              body: Center(child: Text('Attendance not found')));
        }
        final report = matches.first;
        final cubit = context.read<DrillCubit>();

        final canSend = report.students.isNotEmpty && report.unmarked == 0;
        final helper = report.students.isEmpty
            ? 'Add students first'
            : report.unmarked > 0
                ? '${report.unmarked} student${report.unmarked == 1 ? '' : 's'} not set'
                : report.submitted
                    ? 'Sent to the Console'
                    : 'Ready to send';

        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: _blue,
            title: Text(report.label),
            titleTextStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Geist'),
            centerTitle: true,
            actions: [
PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: (v) {
                  if (v == 'present') _markAllPresent();
                  if (v == 'import') _importList(report);
                  if (v == 'save') _saveAsList(report);
                  if (v == 'edit') _edit(report);
                  if (v == 'delete') _delete(report);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'present',
                    enabled: report.students.isNotEmpty,
                    child: const Text('Mark all present'),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: Text('Add from class list'),
                  ),
                  PopupMenuItem(
                    value: 'save',
                    enabled: report.students.isNotEmpty,
                    child: const Text('Save as class list'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit details'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete attendance'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (state.drillActive)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFB3261E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'DRILL  •  ${DrillCubit.formatDuration(state.elapsed)}'
                    '${report.submitted ? "  •  report sent" : ""}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Geist'),
                  ),
                ),

              // report details
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.soft(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(Icons.schedule, formatStamp(report.eventTime)),
                    _InfoRow(Icons.groups,
                        'Grade ${report.grade} - ${report.section}'),
                    _InfoRow(Icons.place, report.site),
                    _InfoRow(Icons.warning_amber, report.emergencyType),
                  ],
                ),
              ),

              // add student
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _addStudent(),
                        decoration: InputDecoration(
                          hintText: tr(context, 'Student name'),
                          hintStyle: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontFamily: 'Geist'),
                          filled: true,
                          fillColor: AppColors.field(context),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _addStudent,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),

              // table header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 30, child: Text('#', style: _headerStyle)),
                    Expanded(child: Text('Name', style: _headerStyle)),
                    SizedBox(
                      width: 128,
                      child: Text('Status', style: _headerStyle),
                    ),
                  ],
                ),
              ),

              // table body
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.field(context)),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10)),
                  ),
                  child: report.students.isEmpty
                      ? const Center(
                          child: Text('No students yet. Add names above.',
                              style: TextStyle(
                                  color: _blue, fontFamily: 'Geist')))
                      : ListView.separated(
                          itemCount: report.students.length,
                          separatorBuilder: (_, _) => Divider(
                              height: 1, color: AppColors.field(context)),
                          itemBuilder: (context, i) {
                            final st = report.students[i];
                            return Dismissible(
                              key: ValueKey(st.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red.shade300,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              // delete first; the row disappears when the list updates
                              confirmDismiss: (_) async {
                                await _guard(() =>
                                    cubit.removeStudent(report.id, st.id));
                                return false;
                              },
                              child: _StudentRow(
                                index: i + 1,
                                student: st,
                                gradeSection: report.label,
                                onStatus: (s) => _setStatus(st.id, s),
                                onRename: () => _rename(st),
                              ),
                            );
                          },
                        ),
                ),
              ),

              // summary + send
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in AttendanceStatus.values)
                            _CountChip(
                              color: s.color,
                              text: '${s.label} ${report.countFor(s)}',
                            ),
                          if (report.unmarked > 0)
                            _CountChip(
                              color: Colors.grey,
                              text: 'Not set ${report.unmarked}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              helper,
                              style: TextStyle(
                                fontFamily: 'Geist',
                                color: canSend ? _blue : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: canSend
                                ? () => _guard(() async {
                                      await cubit.submitReport(report.id);
                                      _toast('Report sent to the Console');
                                    })
                                : null,
                            icon: const Icon(Icons.send),
                            label: Text(report.submitted
                                ? 'Resend report'
                                : 'Send report'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const _headerStyle = TextStyle(
    color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Geist');

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3C6E87)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF3C6E87),
                    fontFamily: 'Geist')),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamily: 'Geist',
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.index,
    required this.student,
    required this.gradeSection,
    required this.onStatus,
    required this.onRename,
  });

  final int index;
  final Student student;
  final String gradeSection; // already filled in from the report
  final ValueChanged<AttendanceStatus> onStatus;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final status = student.status;
    final color = status?.color ?? Colors.grey;

    return Container(
      color: AppColors.bg(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.grey, fontFamily: 'Geist')),
          ),
          Expanded(
            child: InkWell(
              onTap: onRename, // tap the name to edit it
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text.verbatim(student.name,
                            style: const TextStyle(
                                fontFamily: 'Geist', fontSize: 15)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 13, color: Colors.grey),
                    ],
                  ),
                  Text(gradeSection,
                      style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11,
                          color: Colors.grey)),
                ],
              ),
            ),
          ),
          Container(
            width: 128,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AttendanceStatus>(
                value: status,
                isExpanded: true,
                isDense: true,
                hint: const Text('Set status',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontFamily: 'Geist')),
                icon: Icon(Icons.arrow_drop_down, color: color),
                items: [
                  for (final s in AttendanceStatus.values)
                    DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(s.label,
                              style: const TextStyle(
                                  fontSize: 13, fontFamily: 'Geist')),
                        ],
                      ),
                    ),
                ],
                onChanged: (s) {
                  if (s != null) onStatus(s);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns its own controller so it is disposed safely with the dialog.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name',
          style: TextStyle(fontFamily: 'Geist', color: Color(0xFF3C6E87))),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: tr(context, 'Student name')),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
