import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';

/// What the "Add Attendance" dialog returns.
class NewReportInput {
  final String grade;
  final String section;
  final String site;
  final String emergencyType;
  final DateTime eventTime;
  final String? copyFromId;

  const NewReportInput({
    required this.grade,
    required this.section,
    required this.site,
    required this.emergencyType,
    required this.eventTime,
    this.copyFromId,
  });
}

/// Dialog: timestamp, grade, section, evacuation site, type of emergency.
/// Pass [initial] to edit an existing report instead of creating one.
class ReportFormDialog extends StatefulWidget {
  const ReportFormDialog({
    super.key,
    this.existing = const [],
    this.initial,
  });

  final List<AttendanceReport> existing;
  final AttendanceReport? initial;

  @override
  State<ReportFormDialog> createState() => _ReportFormDialogState();
}

class _ReportFormDialogState extends State<ReportFormDialog> {
  static const _blue = Color(0xFF3C6E87);

  DateTime _when = DateTime.now();
  String? _grade;
  String _emergency = emergencyTypes.first;
  bool _copy = true;
  String? _error;

  final _section = TextEditingController();
  final _site = TextEditingController();
  final _other = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _when = i.eventTime;
      _grade = gradeOptions.contains(i.grade) ? i.grade : null;
      _section.text = i.section;
      _site.text = i.site;
      if (emergencyTypes.contains(i.emergencyType)) {
        _emergency = i.emergencyType;
      } else {
        _emergency = 'Other';
        _other.text = i.emergencyType;
      }
    }
  }

  @override
  void dispose() {
    _section.dispose();
    _site.dispose();
    _other.dispose();
    super.dispose();
  }

  /// Newest earlier report of the same grade & section that has students.
  AttendanceReport? get _copySource {
    if (widget.initial != null) return null; // editing: nothing to copy
    final g = _grade;
    final s = _section.text.trim().toLowerCase();
    if (g == null || s.isEmpty) return null;
    for (final r in widget.existing) {
      if (r.grade == g &&
          r.section.trim().toLowerCase() == s &&
          r.students.isNotEmpty) {
        return r;
      }
    }
    return null;
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (t == null || !mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  void _submit() {
    final section = _section.text.trim();
    final site = _site.text.trim();
    final emergency =
        _emergency == 'Other' ? _other.text.trim() : _emergency;

    if (_grade == null) {
      setState(() => _error = 'Pick a grade');
      return;
    }
    if (section.isEmpty) {
      setState(() => _error = 'Enter the section');
      return;
    }
    if (site.isEmpty) {
      setState(() => _error = 'Enter the evacuation site');
      return;
    }
    if (emergency.isEmpty) {
      setState(() => _error = 'Enter the type of emergency');
      return;
    }

    Navigator.pop(
      context,
      NewReportInput(
        grade: _grade!,
        section: section,
        site: site,
        emergencyType: emergency,
        eventTime: _when,
        copyFromId: _copy ? _copySource?.id : null,
      ),
    );
  }

  static const _text = TextStyle(color: _blue, fontFamily: 'Geist');

  InputDecoration _dec(String label) => InputDecoration(
        labelText: tr(context, label),
        labelStyle: _text,
        filled: true,
        fillColor: AppColors.field(context).withValues(alpha: 0.35),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _blue),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _blue),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _blue, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final source = _copySource;

    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Attendance' : 'Edit Attendance',
          style: const TextStyle(fontFamily: 'Geist', color: _blue)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // timestamp
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickWhen,
              child: InputDecorator(
                decoration: _dec('Timestamp'),
                child: Row(
                  children: [
                    Expanded(child: Text(formatStamp(_when), style: _text)),
                    const Icon(Icons.edit_calendar, color: _blue, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // grade
            DropdownButtonFormField<String>(
              key: ValueKey(_grade),
              initialValue: _grade,
              decoration: _dec('Grade'),
              style: _text,
              items: [
                for (final g in gradeOptions)
                  DropdownMenuItem(value: g, child: Text('Grade $g')),
              ],
              onChanged: (v) => setState(() => _grade = v),
            ),
            const SizedBox(height: 12),

            // section
            TextField(
              controller: _section,
              style: _text,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Section (e.g. Polaris)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // evacuation site
            TextField(
              controller: _site,
              style: _text,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Evacuation site'),
            ),
            const SizedBox(height: 12),

            // type of emergency: its own boxed section with a choice per disaster
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.07),
                border: Border.all(color: _blue, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type of emergency',
                      style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Geist')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final e in emergencyTypes)
                        ChoiceChip(
                          label: Text(e),
                          selected: _emergency == e,
                          showCheckmark: false,
                          selectedColor: _blue,
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: _blue),
                          labelStyle: TextStyle(
                              color: _emergency == e ? Colors.white : _blue,
                              fontFamily: 'Geist'),
                          onSelected: (_) => setState(() => _emergency = e),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_emergency == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _other,
                style: _text,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Describe the emergency'),
              ),
            ],

            // reuse an earlier student list
            if (source != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _blue,
                value: _copy,
                onChanged: (v) => setState(() => _copy = v),
                title: Text(
                  'Copy ${source.students.length} student(s) from your '
                  'earlier ${source.label} attendance',
                  style: const TextStyle(
                      fontSize: 13, color: _blue, fontFamily: 'Geist'),
                ),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.initial == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
