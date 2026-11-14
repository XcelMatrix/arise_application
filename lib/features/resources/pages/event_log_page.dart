import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/services/local_cache.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/utils/time_format.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';

const _blue = Color(0xFF3C6E87);
const _red = Color(0xFFB3261E);

class _Event {
  _Event({
    required this.time,
    required this.isAlert,
    required this.title,
    required this.body,
    this.endedAt,
    this.active = false,
    this.cancelled = false,
  });

  final DateTime time;
  final bool isAlert;
  final String title;
  final String body;
  final DateTime? endedAt;
  final bool active;
  final bool cancelled;
}

/// A log of past events: emergency alerts and drills, newest first.
/// Saved on the phone, so it can be read with no signal. Records older
/// than 30 days are removed automatically.
class EventLogPage extends StatefulWidget {
  const EventLogPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const EventLogPage());

  @override
  State<EventLogPage> createState() => _EventLogPageState();
}

class _EventLogPageState extends State<EventLogPage> {
  static const _drillsKey = 'event_log_drills';

  List<Map<String, dynamic>> _drills = const [];
  bool _drillsOffline = false;
  String _filter = 'all'; // all | alerts | drills

  @override
  void initState() {
    super.initState();
    context.read<AlertLogCubit>().load();
    _loadDrills();
  }

  Future<void> _loadDrills() async {
    try {
      final data = await Supabase.instance.client
          .from('drills')
          .select('id, status, started_at, ended_at, attendance_reports(emergency_type)')
          .neq('status', 'active')
          .order('started_at', ascending: false)
          .limit(100);
      final rows = [for (final r in data) Map<String, dynamic>.from(r)];
      await LocalCache.save(_drillsKey, rows);
      if (mounted) setState(() => _drills = rows);
    } on PostgrestException {
      // this account is not allowed to see drills: show alerts only
      if (mounted) setState(() => _drills = const []);
    } catch (_) {
      final cached = await LocalCache.readRows(_drillsKey);
      if (mounted) {
        setState(() {
          _drills = cached ?? const [];
          _drillsOffline = true;
        });
      }
    }
  }

  List<_Event> _events(List<Map<String, dynamic>> alerts) {
    DateTime t(Object? v) => DateTime.parse('$v').toLocal();
    final out = <_Event>[];
    for (final r in alerts) {
      final cleared = r['cleared_at'];
      out.add(_Event(
        time: t(r['created_at']),
        isAlert: true,
        title: Tr.t('${r['kind']}'),
        body: localizedAlertRow(r),
        endedAt: cleared == null ? null : t(cleared),
        active: cleared == null,
      ));
    }
    for (final r in _drills) {
      final reps = r['attendance_reports'];
      final type = reps is List && reps.isNotEmpty
          ? '${(reps.first as Map)['emergency_type'] ?? ''}'
          : '';
      out.add(_Event(
        time: t(r['started_at']),
        isAlert: false,
        title: type.isEmpty ? Tr.t('Drill') : '${Tr.t('Drill')}: ${Tr.t(type)}',
        body: '',
        endedAt: r['ended_at'] == null ? null : t(r['ended_at']),
        cancelled: r['status'] == 'cancelled',
      ));
    }
    out.sort((a, b) => b.time.compareTo(a.time));
    return [
      for (final e in out)
        if (_filter == 'all' ||
            (_filter == 'alerts' && e.isAlert) ||
            (_filter == 'drills' && !e.isAlert))
          e,
    ];
  }

  String _stamp(DateTime d) =>
      '${Tr.months[d.month - 1]} ${d.day}, ${d.year}  ${TimeFormat.clock(d)}';

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final alertState = context.watch<AlertLogCubit>().state;
    final events = _events(alertState.rows);
    final offline = alertState.offline || _drillsOffline;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Event log'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: !alertState.loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await context.read<AlertLogCubit>().load();
                await _loadDrills();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final f in const [
                        ('all', 'All'),
                        ('alerts', 'Alerts'),
                        ('drills', 'Drills'),
                      ])
                        ChoiceChip(
                          label: Text(f.$2),
                          selected: _filter == f.$1,
                          selectedColor: _blue,
                          labelStyle: TextStyle(
                              color: _filter == f.$1 ? Colors.white : null,
                              fontFamily: 'Geist'),
                          onSelected: (_) => setState(() => _filter = f.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Offline. Showing the last saved copy.',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ),
                      ]),
                    ),
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                          child: Text('No past events yet.',
                              style: const TextStyle(color: Colors.grey))),
                    ),
                  for (final e in events)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: e.active ? Border.all(color: _red) : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: e.isAlert ? _red : _blue,
                            child: Icon(
                                e.isAlert
                                    ? Icons.warning_amber_rounded
                                    : Icons.directions_run,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.verbatim(
                                  e.isAlert
                                      ? '${Tr.t('Alert')}: ${e.title}'
                                      : e.title,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text(context),
                                      fontFamily: 'Geist'),
                                ),
                                if (e.body.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text.verbatim(e.body,
                                        style: TextStyle(
                                            color: AppColors.text(context))),
                                  ),
                                const SizedBox(height: 4),
                                Text.verbatim(_stamp(e.time),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                if (e.isAlert)
                                  Text.verbatim(
                                    e.active
                                        ? Tr.t('Still active')
                                        : '${Tr.t('All clear')}: ${TimeFormat.clock(e.endedAt!)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: e.active
                                            ? _red
                                            : const Color(0xFF2E7D32)),
                                  )
                                else if (e.cancelled)
                                  Text(
                                    'Cancelled',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  )
                                else if (e.endedAt != null)
                                  Text.verbatim(
                                    '${Tr.t('Evacuation time')}: ${DrillCubit.formatDurationWords(e.endedAt!.difference(e.time))}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Past events are kept for 30 days.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            ),
    );
  }
}
