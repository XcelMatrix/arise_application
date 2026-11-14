import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';
import 'package:arise_application/core/utils/time_format.dart';

/// Teachers and admins: who has answered "I'm safe" for an alert, who needs
/// help and who has not answered yet. Updates live.
class CheckInRosterPage extends StatefulWidget {
  const CheckInRosterPage({super.key, required this.alertId});
  final String alertId;

  static Route<void> route(String alertId) => MaterialPageRoute(
      builder: (_) => CheckInRosterPage(alertId: alertId));

  @override
  State<CheckInRosterPage> createState() => _CheckInRosterPageState();
}

class _CheckInRosterPageState extends State<CheckInRosterPage> {
  static const _blue = Color(0xFF3C6E87);
  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFB3261E);
  static const _grey = Color(0xFF757575);

  final _sb = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _poll;
  List<Map<String, dynamic>> _rows = const [];
  bool _loaded = false;
  String? _error;
  String _filter = 'none'; // none | help | safe | all

  @override
  void initState() {
    super.initState();
    _load();
    try {
      _channel = _sb
          .channel('checkins-${widget.alertId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'safe_checkins',
            callback: (_) => _load(),
          )
          .subscribe();
    } catch (_) {}
    // in case the live connection drops
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _sb
          .rpc('alert_roster', params: {'p_alert': widget.alertId});
      if (!mounted) return;
      setState(() {
        _rows = [for (final x in r as List) Map<String, dynamic>.from(x as Map)];
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _error = e is PostgrestException ? e.message : '$e';
      });
    }
  }

  int _count(String? s) => _rows.where((r) => r['status'] == s).length;

  bool _reminding = false;

  /// Everyone who has not answered sees the warning again (and gets a
  /// notification if the app is closed).
  Future<void> _remind(int n) async {
    final m = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text.verbatim('${tr(ctx, 'Remind')} $n ${tr(ctx, 'people?')}'),
        content: const Text(
            'The warning appears again on the phones of everyone who has not answered yet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send reminder')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _reminding = true);
    try {
      final sent = await _sb.rpc('remind_non_responders',
          params: {'p_alert': widget.alertId});
      m.showSnackBar(SnackBar(
          content: Text.verbatim('${tr(context, 'Reminder sent to')} $sent ${tr(context, 'people.')}')));
    } catch (e) {
      m.showSnackBar(SnackBar(
          content: Text.verbatim(e is PostgrestException ? e.message : '$e')));
    } finally {
      if (mounted) setState(() => _reminding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final safe = _count('safe');
    final help = _count('help');
    final none = _count(null);
    final shown = [
      for (final r in _rows)
        if (_filter == 'all' ||
            (_filter == 'none' && r['status'] == null) ||
            (_filter == 'help' && r['status'] == 'help') ||
            (_filter == 'safe' && r['status'] == 'safe'))
          r,
    ];
    Widget chip(String key, String label, int n, Color c) => ChoiceChip(
          label: Text.verbatim('${tr(context, label)} ($n)'),
          selected: _filter == key,
          selectedColor: c,
          showCheckmark: false,
          labelStyle: TextStyle(
              color: _filter == key ? Colors.white : null, fontFamily: 'Geist'),
          onSelected: (_) => setState(() => _filter = key),
        );

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Safe check-ins'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text.verbatim(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.verbatim(
                            '$safe / ${_rows.length} ${tr(context, 'safe')}',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _green,
                                fontFamily: 'Geist')),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _rows.isEmpty ? 0 : safe / _rows.length,
                          minHeight: 8,
                          color: _green,
                          backgroundColor: const Color(0xFFE0E0E0),
                        ),
                      ],
                    ),
                  ),
                  if (context.select<AccountCubit, bool>(
                          (c) => c.state.canAccess(Feature.emergencyAlert)) &&
                      none > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _red),
                        onPressed: _reminding ? null : () => _remind(none),
                        icon: const Icon(Icons.notifications_active),
                        label: Text.verbatim(
                            '${tr(context, 'Remind')} $none ${tr(context, 'who have not answered')}'),
                      ),
                    ),
                  Builder(builder: (context) {
                    final a = context.watch<AlertCubit>().state.active;
                    final t = a?.id == widget.alertId ? a?.remindedAt : null;
                    return t == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text.verbatim(
                                '${tr(context, 'Last reminder')}: ${TimeFormat.clock(t)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          );
                  }),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      chip('none', 'Not answered', none, _grey),
                      const SizedBox(width: 8),
                      chip('help', 'Need help', help, _red),
                      const SizedBox(width: 8),
                      chip('safe', 'Safe', safe, _green),
                      const SizedBox(width: 8),
                      chip('all', 'Everyone', _rows.length, _blue),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: Text('Nobody here.',
                              style: TextStyle(color: Colors.grey))),
                    ),
                  for (final r in shown) _row(context, r),
                ],
              ),
            ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> r) {
    final s = r['status'] as String?;
    final c = s == 'safe' ? _green : (s == 'help' ? _red : _grey);
    final icon = s == 'safe'
        ? Icons.check_circle
        : (s == 'help' ? Icons.sos : Icons.hourglass_empty);
    final grade = r['grade'] as String?;
    final section = r['section'] as String?;
    final role = '${r['role_name']}';
    final where = grade == null || grade.isEmpty
        ? tr(context, role == 'member' ? 'student' : role)
        : '${tr(context, 'Grade')} $grade · ${section ?? ''}';
    final at = DateTime.tryParse('${r['responded_at']}')?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: s == 'help' ? Border.all(color: _red, width: 1.5) : null,
      ),
      child: Row(children: [
        Icon(icon, color: c),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.verbatim('${r['name']}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                      fontFamily: 'Geist')),
              Text.verbatim(where,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Text.verbatim(
            s == null
                ? tr(context, 'No answer')
                : '${tr(context, s == 'safe' ? 'Safe' : 'Needs help')}'
                    '${at == null ? '' : ' · ${Tr.months[at.month - 1]} ${at.day}'}',
            style: TextStyle(
                color: c, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
