import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/services/local_cache.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/console/models/drill_record.dart';
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
              stem, AttendanceExport.drillsPdf(_drills, period: _periodLabel), subject);
        } else {
          await ExportFiles.shareCsv(stem, AttendanceExport.drillsCsv(_drills), subject);
        }
      }
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stat(BuildContext context, String label, String value, Color c) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text.verbatim(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: c)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );

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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Period',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                        fontFamily: 'Geist')),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: _days,
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
                    title: Text('Include names of missing and injured students'),
                    subtitle: Text('Leave off if the file will be shared widely.',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Text(
                      isAdmin
                          ? 'Includes the reports of every teacher.'
                          : 'Includes your own reports.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                    color: AppColors.text(context),
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
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
