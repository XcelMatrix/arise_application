import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/theme/stat_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/services/local_cache.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/console/models/drill_record.dart';
import 'package:arise_application/features/reports/models/drill_assessment.dart';
import 'package:arise_application/features/reports/services/attendance_export.dart';
import 'package:arise_application/features/reports/services/export_files.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';

const _blue = Color(0xFF3C6E87);

/// Attendance and drill summaries over a period, as PDF or CSV. The file is
/// handed to the phone's share sheet (save to Files, Drive, email...).
/// Labels in the file follow the language picked in Settings.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ReportsPage());

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _sb = Supabase.instance.client;

  String _kind = 'attendance'; // attendance | drills
  int _days = 30; // 0 = everything that is kept
  bool _names = false;

  bool _loading = true;
  bool _offline = false;
  bool _busy = false;
  List<AttendanceReport> _reports = const [];
  List<DrillRecord> _drills = const [];
  Map<String, DrillAssessment> _assess = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? get _since =>
      _days == 0 ? null : DateTime.now().subtract(Duration(days: _days));

  Future<void> _load() async {
    setState(() => _loading = true);
    final since = _since;
    final isAdmin = context.read<AccountCubit>().state.rank >= 3;
    final myId = _sb.auth.currentUser?.id;
    try {
      if (_kind == 'attendance') {
        var q = _sb
            .from('attendance_reports')
            .select('*, report_students(id, name, status, created_at)');
        if (!isAdmin && myId != null) q = q.eq('owner_id', myId);
        if (since != null) {
          q = q.gte('event_time', since.toUtc().toIso8601String());
        }
        final data = await q.order('event_time', ascending: false).limit(500);
        _reports = [
          for (final r in data)
            AttendanceReport.fromRow(Map<String, dynamic>.from(r)),
        ];
      } else {
        var q = _sb
            .from('drills')
            .select('*, attendance_reports(*, report_students(id, name, status, created_at))')
            .neq('status', 'active');
        if (since != null) {
          q = q.gte('started_at', since.toUtc().toIso8601String());
        }
        final data = await q.order('started_at', ascending: false).limit(100);
        _drills = [
          for (final r in data) DrillRecord.fromRow(Map<String, dynamic>.from(r)),
        ];
        // the assessments written for these drills (none yet if the table is
        // not set up: the list just shows "Not assessed")
        try {
          final a = await _sb.from('drill_assessments').select();
          _assess = {
            for (final r in a)
              '${r['drill_id']}':
                  DrillAssessment.fromRow(Map<String, dynamic>.from(r)),
          };
        } catch (_) {
          _assess = const {};
        }
      }
      _offline = false;
    } catch (e) {
      if (e is PostgrestException) {
        _toast(e.message);
      } else {
        // no signal: use the copy saved on this phone
        _offline = true;
        if (_kind == 'attendance') {
          final rows =
              await LocalCache.readRows('attendance_mine_$myId') ?? const [];
          _reports = [
            for (final r in rows)
              if (since == null ||
                  DateTime.parse(r['event_time'] as String).isAfter(since))
                AttendanceReport.fromRow(r),
          ];
        } else {
          final rows = await LocalCache.readRows('drill_history') ?? const [];
          _drills = [
            for (final r in rows)
              if (since == null ||
                  DateTime.parse(r['started_at'] as String).isAfter(since))
                DrillRecord.fromRow(r),
          ];
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text.verbatim(m)));
  }

  String get _periodLabel => _days == 0
      ? Tr.t('Everything that is kept')
      : Tr.t(_days == 7 ? 'Last 7 days' : 'Last 30 days');

  int get _count => _kind == 'attendance' ? _reports.length : _drills.length;

  Future<void> _export(bool pdf) async {
    if (_count == 0) return _toast(Tr.t('Nothing to export for this period.'));
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      if (_kind == 'attendance') {
        final stem = ExportFiles.stem('attendance_summary', now);
        final subject = 'ARISE ${Tr.t('Attendance summary')}';
        if (pdf) {
          await ExportFiles.sharePdf(
              stem,
              AttendanceExport.attendancePdf(_reports,
                  period: _periodLabel, names: _names),
              subject);
        } else {
          await ExportFiles.shareCsv(
              stem, AttendanceExport.attendanceCsv(_reports, names: _names), subject);
        }
      } else {
        final stem = ExportFiles.stem('drill_summary', now);
        final subject = 'ARISE ${Tr.t('Drill summary')}';
        if (pdf) {
          await ExportFiles.sharePdf(
              stem, AttendanceExport.drillsPdf(_drills,
                  period: _periodLabel, assessments: _assess),
              subject);
        } else {
          await ExportFiles.shareCsv(
              stem, AttendanceExport.drillsCsv(_drills, _assess), subject);
        }
      }
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stat(BuildContext context, String label, String value, Color c) {
    final pal = StatColors.of(context, c);
    final fg = pal.text;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: pal.box,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text.verbatim(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: fg)),
          Text(label, style: TextStyle(fontSize: 11, color: fg)),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------- assessment

  Future<void> _assessDrill(DrillRecord d) async {
    final existing = _assess[d.id];
    final answers = <String, int>{...?existing?.answers};
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final live = DrillAssessment(d.id, answers, '', null);
          final sent = d.reports.where((r) => r.submitted).length;
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.88,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Drill Assessment',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _blue,
                                fontFamily: 'Geist')),
                        const SizedBox(height: 4),
                        Text.verbatim(
                            '${drillDate(d.started)}'
                            '${d.type.isEmpty ? '' : '  •  ${Tr.t(d.type)}'}',
                            style: const TextStyle(color: _blue)),
                        Text.verbatim(
                            '${d.duration == null ? '' : '${Tr.t('Evacuation time')}: ${DrillCubit.formatDurationWords(d.duration!)}  •  '}'
                            '${Tr.t('Reports sent')}: $sent/${d.reports.length}',
                            style: const TextStyle(fontSize: 12, color: _blue)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final item in assessmentItems) ...[
                          Text(item.label,
                              style: const TextStyle(
                                  color: _blue, fontFamily: 'Geist')),
                          const SizedBox(height: 4),
                          SegmentedButton<int>(
                            emptySelectionAllowed: true,
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              foregroundColor: _blue,
                              selectedForegroundColor: Colors.white,
                              selectedBackgroundColor: _blue,
                              side: const BorderSide(color: _blue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            segments: const [
                              ButtonSegment(value: 2, label: Text('Yes')),
                              ButtonSegment(value: 1, label: Text('Partly')),
                              ButtonSegment(value: 0, label: Text('No')),
                            ],
                            selected: answers.containsKey(item.key)
                                ? {answers[item.key]!}
                                : <int>{},
                            onSelectionChanged: (v) => setLocal(() {
                              if (v.isEmpty) {
                                answers.remove(item.key);
                              } else {
                                answers[item.key] = v.first;
                              }
                            }),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: notes,
                          minLines: 2,
                          maxLines: 5,
                          maxLength: 500,
                          style: const TextStyle(color: _blue),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: tr(ctx, 'Notes (optional)'),
                            labelStyle: const TextStyle(color: _blue),
                            border: const OutlineInputBorder(
                                borderSide: BorderSide(color: _blue)),
                            enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: _blue)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(children: [
                      Expanded(
                        child: Text.verbatim(
                            answers.isEmpty
                                ? ''
                                : '${live.score}%  •  ${Tr.t(live.rating)}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _blue)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white),
                        onPressed:
                            answers.isEmpty ? null : () => Navigator.pop(ctx, true),
                        child: const Text('Save assessment'),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    final note = notes.text.trim();
    Future.delayed(const Duration(milliseconds: 600), notes.dispose);
    if (saved != true || !mounted) return;
    try {
      await _sb.from('drill_assessments').upsert({
        'drill_id': d.id,
        'answers': answers,
        'notes': note,
        'score': DrillAssessment(d.id, answers, '', null).score,
        'assessed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'drill_id');
      await _load();
      _toast(Tr.t('Assessment saved.'));
    } catch (e) {
      _toast(e is PostgrestException ? e.message : '$e');
    }
  }

  Widget _assessmentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [
          Icon(Icons.fact_check, color: _blue),
          SizedBox(width: 8),
          Text('Drill Assessment',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _blue,
                  fontFamily: 'Geist')),
        ]),
        const SizedBox(height: 4),
        Text(
            'After a drill, rate how it went. The scores are included in the exports.',
            style: const TextStyle(fontSize: 12, color: _blue)),
        const SizedBox(height: 8),
        if (_drills.isEmpty)
          Text('No drills in this period.',
              style: const TextStyle(color: _blue)),
        for (final d in _drills)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border.all(color: AppColors.border(context), width: 1.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              onTap: () => _assessDrill(d),
              title: Text.verbatim(
                  '${drillDate(d.started)}${d.type.isEmpty ? '' : '  •  ${Tr.t(d.type)}'}',
                  style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Geist')),
              subtitle: _assess[d.id] == null
                  ? Text('Not assessed yet',
                      style: const TextStyle(color: _blue, fontSize: 12))
                  : Text.verbatim(
                      '${_assess[d.id]!.score}%  •  ${Tr.t(_assess[d.id]!.rating)}',
                      style: const TextStyle(color: _blue, fontSize: 12)),
              trailing: Icon(
                  _assess[d.id] == null ? Icons.rate_review : Icons.edit,
                  color: _blue),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final isAdmin = context.watch<AccountCubit>().state.rank >= 3;

    Widget preview;
    if (_kind == 'attendance') {
      final t = AttendanceTotals(_reports);
      preview = Row(children: [
        _stat(context, tr(context, 'Present'), '${t.present}', AttendanceStatus.present.color),
        _stat(context, tr(context, 'Absent'), '${t.absent}', AttendanceStatus.absent.color),
        _stat(context, tr(context, 'Missing'), '${t.missing}', AttendanceStatus.missing.color),
        _stat(context, tr(context, 'Injured'), '${t.injured}', AttendanceStatus.injured.color),
      ]);
    } else {
      final done = _drills.where((d) => d.status == 'complete').length;
      preview = Row(children: [
        _stat(context, tr(context, 'Drills'), '${_drills.length}', _blue),
        _stat(context, tr(context, 'Complete'), '$done', const Color(0xFF2E7D32)),
        _stat(context, tr(context, 'Cancelled'), '${_drills.length - done}', Colors.grey),
      ]);
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Reports'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: const [ProfileMenuButton()],
      ),
      endDrawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              foregroundColor: _blue,
              backgroundColor: Colors.transparent,
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: _blue,
              side: const BorderSide(color: _blue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            segments: [
              ButtonSegment(
                  value: 'attendance',
                  icon: const Icon(Icons.assignment_turned_in),
                  label: Text('Attendance')),
              ButtonSegment(
                  value: 'drills',
                  icon: const Icon(Icons.directions_run),
                  label: Text('Drills')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) {
              setState(() => _kind = s.first);
              _load();
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border.all(color: AppColors.border(context), width: 1.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Period',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _blue,
                        fontFamily: 'Geist')),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: _days,
                  style: const TextStyle(color: _blue, fontFamily: 'Geist'),
                  items: [
                    DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                    DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                    DropdownMenuItem(
                        value: 0, child: Text('Everything that is kept')),
                  ],
                  onChanged: (v) {
                    setState(() => _days = v ?? 30);
                    _load();
                  },
                ),
                if (_kind == 'attendance') ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _names,
                    onChanged: (v) => setState(() => _names = v),
                    activeTrackColor: _blue,
                    title: Text('Include names of missing and injured students',
                        style: const TextStyle(color: _blue)),
                    subtitle: Text('Leave off if the file will be shared widely.',
                        style: const TextStyle(fontSize: 12, color: _blue)),
                  ),
                  Text(
                      isAdmin
                          ? 'Includes the reports of every teacher.'
                          : 'Includes your own reports.',
                      style: const TextStyle(fontSize: 12, color: _blue)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_offline)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Offline. Showing the last saved copy.',
                      style: const TextStyle(color: _blue, fontSize: 12)),
                ),
              ]),
            ),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else ...[
            Text.verbatim(
                '${_kind == 'attendance' ? Tr.t('Reports') : Tr.t('Drills')}: $_count',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _blue,
                    fontFamily: 'Geist')),
            const SizedBox(height: 8),
            preview,
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _busy ? null : () => _export(true),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text('Export as PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _busy ? null : () => _export(false),
                  icon: const Icon(Icons.table_chart),
                  label: Text('Export as CSV'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
                'CSV opens in Excel or Google Sheets. For one drill with every student, open Drill history.',
                style: const TextStyle(fontSize: 12, color: _blue)),
            if (_kind == 'drills') ...[
              const SizedBox(height: 24),
              _assessmentSection(context),
              const SizedBox(height: 24),
            ],
          ],
        ],
      ),
    );
  }
}
