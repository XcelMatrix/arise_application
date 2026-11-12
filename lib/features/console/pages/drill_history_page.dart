import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/console/models/drill_record.dart';
import 'package:arise_application/features/console/services/report_export.dart';
import 'package:arise_application/core/services/local_cache.dart';
import 'package:arise_application/core/theme/app_colors.dart';

const _blue = Color(0xFF3C6E87);

/// Past drills with totals and a report for each.
class DrillHistoryPage extends StatefulWidget {
  const DrillHistoryPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (context) => const DrillHistoryPage());

  @override
  State<DrillHistoryPage> createState() => _DrillHistoryPageState();
}

class _DrillHistoryPageState extends State<DrillHistoryPage> {
  List<DrillRecord>? _drills;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> rows;
    try {
      final data = await Supabase.instance.client
          .from('drills')
          .select('*, attendance_reports(*, report_students(id, name, status, created_at))')
          .neq('status', 'active')
          .order('started_at', ascending: false)
          .limit(50);
      rows = [for (final r in data) Map<String, dynamic>.from(r)];
      await LocalCache.save('drill_history', rows);
      _offline = false;
    } catch (_) {
      rows = await LocalCache.readRows('drill_history') ?? [];
      _offline = true;
    }
    if (mounted) {
      setState(() => _drills = [for (final r in rows) DrillRecord.fromRow(r)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _drills;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Drill history'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: d == null
          ? const FlashingLogo()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_offline)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Offline. Showing the last saved copy.',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  if (d.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: Text('No drills yet.',
                              style: TextStyle(color: Colors.grey))),
                    ),
                  for (final r in d)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => _DrillReportPage(record: r)),
                        ),
                        leading: Icon(
                          r.status == 'complete'
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: r.status == 'complete'
                              ? const Color(0xFF2E7D32)
                              : Colors.grey,
                        ),
                        title: Text.verbatim(drillDate(r.started),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.text(context),
                                fontFamily: 'Geist')),
                        subtitle: Text.verbatim([
                          if (r.type.isNotEmpty) tr(context, r.type),
                          if (r.duration != null)
                            DrillCubit.formatDurationWords(r.duration!),
                          if (r.status == 'cancelled') tr(context, 'Cancelled'),
                        ].join('  •  ')),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DrillReportPage extends StatelessWidget {
  const _DrillReportPage({required this.record});
  final DrillRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Drill report'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: tr(context, 'Export'),
            icon: const Icon(Icons.ios_share),
            onSelected: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                if (v == 'copy') {
                  await Clipboard.setData(ClipboardData(text: r.asText()));
                  messenger.showSnackBar(
                      const SnackBar(content: Text('Report copied.')));
                } else if (v == 'pdf') {
                  await ReportExport.sharePdf(r);
                } else {
                  await ReportExport.shareCsv(r);
                }
              } catch (e) {
                messenger.showSnackBar(
                    SnackBar(content: Text.verbatim('$e')));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
              PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              PopupMenuItem(value: 'copy', child: Text('Copy report')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text.verbatim(drillDate(r.started),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _blue,
                  fontFamily: 'Geist')),
          if (r.duration != null)
            Text.verbatim(
                '${tr(context, 'Evacuation time')}: ${DrillCubit.formatDurationWords(r.duration!)}'),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in AttendanceStatus.values)
              Chip(
                label: Text.verbatim('${tr(context, s.label)} ${r.total(s)}',
                    style: TextStyle(
                        color: s.color, fontWeight: FontWeight.bold)),
                backgroundColor: s.color.withValues(alpha: 0.12),
                side: BorderSide.none,
              ),
          ]),
          const SizedBox(height: 14),
          for (final rep in r.reports)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.verbatim('${rep.consoleLabel}  •  ${rep.site}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                          fontFamily: 'Geist')),
                  Text.verbatim(
                      'Present ${rep.present} · Absent ${rep.absent} · Missing ${rep.missing} · Injured ${rep.injured}'
                      '${rep.submitted ? '' : '  (${tr(context, 'not sent')})'}'),
                  for (final s in [
                    AttendanceStatus.missing,
                    AttendanceStatus.injured
                  ])
                    if (rep.namesFor(s).isNotEmpty)
                      Text.verbatim('${s.label}: ${rep.namesFor(s).join(', ')}',
                          style: TextStyle(color: s.color, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
