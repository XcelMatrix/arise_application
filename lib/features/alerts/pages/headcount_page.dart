import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/translations/translated_text.dart';

const _blue = Color(0xFF3C6E87);
const _green = Color(0xFF2E7D32);
const _red = Color(0xFFB3261E);
const _orange = Color(0xFFEF6C00);
const _grey = Color(0xFF757575);

AppBar _bar(String title) => AppBar(
      backgroundColor: _blue,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(title),
      titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist'),
      centerTitle: true,
    );

String _err(Object e) => e is PostgrestException ? e.message : '$e';

/// Teachers: every class list with how many students are accounted for.
/// Admins see the lists of all teachers.
class HeadcountPage extends StatefulWidget {
  const HeadcountPage({super.key, required this.alertId});
  final String alertId;

  static Route<void> route(String alertId) =>
      MaterialPageRoute(builder: (_) => HeadcountPage(alertId: alertId));

  @override
  State<HeadcountPage> createState() => _HeadcountPageState();
}

class _HeadcountPageState extends State<HeadcountPage> {
  final _sb = Supabase.instance.client;
  Timer? _poll;
  List<Map<String, dynamic>> _rows = const [];
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _sb
          .rpc('headcount_summary', params: {'p_alert': widget.alertId});
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
        _error = _err(e);
      });
    }
  }

  int _sum(String k) => _rows.fold<int>(0, (n, r) => n + ((r[k] as num?)?.toInt() ?? 0));

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final total = _sum('total');
    final safe = _sum('safe_n');
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _bar('Class headcount'),
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
                  if (_rows.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                          'No class lists yet. Create one in Attendance > Class lists, or import a spreadsheet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ),
                  if (_rows.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.verbatim(
                              '$safe / $total ${tr(context, 'accounted for')}',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _green,
                                  fontFamily: 'Geist')),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : safe / total,
                            minHeight: 8,
                            color: _green,
                            backgroundColor: const Color(0xFFE0E0E0),
                          ),
                          const SizedBox(height: 8),
                          Text.verbatim(
                              '${_sum('missing_n')} ${tr(context, 'missing')} · '
                              '${_sum('injured_n')} ${tr(context, 'injured')} · '
                              '${_sum('help_n')} ${tr(context, 'asked for help')} · '
                              '${_sum('unmarked_n')} ${tr(context, 'not marked')}',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  for (final r in _rows) _tile(context, r),
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> r) {
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    final total = n('total');
    final done = n('safe_n');
    final problem = n('missing_n') + n('injured_n') + n('help_n');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: problem > 0 ? Border.all(color: _red, width: 1.4) : null,
      ),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => HeadcountListPage(
                      alertId: widget.alertId,
                      listId: '${r['list_id']}',
                      title: '${r['list_name']}')));
          _load();
        },
        leading: Icon(done == total && total > 0 ? Icons.check_circle : Icons.groups,
            color: done == total && total > 0 ? _green : _blue),
        title: Text.verbatim('${r['list_name']}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
                fontFamily: 'Geist')),
        subtitle: Text.verbatim(
            '${r['teacher'] ?? ''}\n$done / $total ${tr(context, 'accounted for')}'
            '${problem > 0 ? ' · $problem ${tr(context, 'need attention')}' : ''}'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// One class list: mark each student safe, missing or injured.
/// Students who tapped "I'm safe" on their own phone already show a tick.
class HeadcountListPage extends StatefulWidget {
  const HeadcountListPage(
      {super.key,
      required this.alertId,
      required this.listId,
      required this.title});
  final String alertId;
  final String listId;
  final String title;

  @override
  State<HeadcountListPage> createState() => _HeadcountListPageState();
}

class _HeadcountListPageState extends State<HeadcountListPage> {
  final _sb = Supabase.instance.client;
  Timer? _poll;
  List<Map<String, dynamic>> _rows = const [];
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    // so students who check in on their own phone appear on their own
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text.verbatim(m)));
  }

  Future<void> _load() async {
    if (_busy) return;
    try {
      final r = await _sb.rpc('class_headcount',
          params: {'p_alert': widget.alertId, 'p_list': widget.listId});
      if (!mounted) return;
      setState(() {
        _rows = [for (final x in r as List) Map<String, dynamic>.from(x as Map)];
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      _toast(_err(e));
    }
  }

  /// teacher's mark, otherwise what the student reported on their phone
  String? _effective(Map<String, dynamic> r) {
    final t = r['status'] as String?;
    if (t != null) return t;
    final s = r['self_status'] as String?;
    return s == 'safe' ? 'safe' : (s == 'help' ? 'help' : null);
  }

  Future<void> _mark(Map<String, dynamic> r, String status) async {
    // tapping the same button again clears the mark
    final now = r['status'] as String?;
    final send = now == status ? 'clear' : status;
    final old = now;
    setState(() => r['status'] = send == 'clear' ? null : send);
    try {
      await _sb.rpc('set_headcount', params: {
        'p_alert': widget.alertId,
        'p_list': widget.listId,
        'p_student': r['student'],
        'p_status': send,
      });
    } catch (e) {
      if (mounted) setState(() => r['status'] = old);
      _toast(_err(e));
    }
  }

  Future<void> _markAll() async {
    setState(() => _busy = true);
    try {
      final n = await _sb.rpc('mark_list_safe',
          params: {'p_alert': widget.alertId, 'p_list': widget.listId});
      _toast('$n ${tr(context, 'students marked safe.')}');
    } catch (e) {
      _toast(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    int count(String s) => _rows.where((r) => _effective(r) == s).length;
    final none = _rows.where((r) => _effective(r) == null).length;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _bar(widget.title),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    Expanded(
                      child: Text.verbatim(
                          '${count('safe')} ${tr(context, 'safe')} · '
                          '${count('missing')} ${tr(context, 'missing')} · '
                          '${count('injured')} ${tr(context, 'injured')} · '
                          '$none ${tr(context, 'not marked')}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      onPressed: _busy || none == 0 ? null : _markAll,
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark the rest safe'),
                    ),
                  ]),
                ),
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(
                          child: Text('This list has no students.',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _rows.length,
                          itemBuilder: (_, i) => _row(context, _rows[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> r) {
    final eff = _effective(r);
    final mine = r['status'] as String?;
    final self = r['self_status'] as String?;
    Color color(String? s) => s == 'safe'
        ? _green
        : (s == 'missing' ? _orange : (s == 'injured' || s == 'help' ? _red : _grey));

    Widget btn(String status, IconData icon, Color c) => IconButton(
          tooltip: tr(context, status == 'safe' ? 'Safe' : (status == 'missing' ? 'Missing' : 'Injured')),
          onPressed: () => _mark(r, status),
          style: IconButton.styleFrom(
              backgroundColor: mine == status ? c : null,
              foregroundColor: mine == status ? Colors.white : c),
          icon: Icon(icon),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: eff == null ? null : Border(left: BorderSide(color: color(eff), width: 4)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.verbatim('${r['student']}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                      fontFamily: 'Geist')),
              if (self != null && mine == null)
                Row(children: [
                  Icon(self == 'safe' ? Icons.phone_android : Icons.sos,
                      size: 14, color: color(eff)),
                  const SizedBox(width: 4),
                  Text(self == 'safe'
                      ? 'Marked safe on their phone'
                      : 'Asked for help on their phone',
                      style: TextStyle(fontSize: 12, color: color(eff))),
                ]),
            ],
          ),
        ),
        btn('safe', Icons.check_circle_outline, _green),
        btn('missing', Icons.person_search, _orange),
        btn('injured', Icons.healing, _red),
      ]),
    );
  }
}
