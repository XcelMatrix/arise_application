import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart' show formatStamp;
import 'package:arise_application/translations/translated_text.dart';

/// Admin tools: people and roles, who can use which feature, and the
/// 30-day clean-up of old records. Everything is enforced by the database
/// (admin-only functions in 12_buildings_retention_admin.sql).
class AdminToolsPage extends StatelessWidget {
  const AdminToolsPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const AdminToolsPage());

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AccountCubit>().state.rank >= 3;
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _blue,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Admin tools'),
          titleTextStyle: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        body: const Center(child: Text('Admins only.')),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(
          backgroundColor: _blue,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Admin tools'),
          titleTextStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Geist'),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFFD0DDE5),
            tabs: [
              Tab(text: tr(context, 'People')),
              Tab(text: tr(context, 'Access')),
              Tab(text: tr(context, 'Data')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UsersTab(), _AccessTab(), _DataTab()],
        ),
      ),
    );
  }
}

SupabaseClient get _sb => Supabase.instance.client;

void _toast(BuildContext context, String m) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text.verbatim(m)));
}

String _errorMessage(Object e) => e is PostgrestException ? e.message : '$e';

// ---------------------------------------------------------------- people

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Map<String, dynamic>>? _users;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _sb.rpc('admin_list_users') as List;
      if (!mounted) return;
      setState(() {
        _users = [for (final r in rows) Map<String, dynamic>.from(r as Map)];
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errText(e));
    }
  }

  String _errText(Object e) => e is PostgrestException ? e.message : '$e';

  String _name(Map<String, dynamic> u) {
    final d = (u['display_name'] as String?)?.trim() ?? '';
    return d.isNotEmpty ? d : (u['username'] as String? ?? '');
  }

  Future<void> _setRole(Map<String, dynamic> u, String role) async {
    try {
      await _sb.rpc('admin_set_role', params: {'p_user': u['user_id'], 'p_role': role});
      await _load();
    } catch (e) {
      if (mounted) _toast(context, _errorMessage(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text.verbatim(
            '${_name(u)}\n\n${tr(ctx, 'Their chat messages are deleted. Other records they made stay, without their name.')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sb.rpc('admin_delete_user', params: {'p_user': u['user_id']});
      await _load();
    } catch (e) {
      if (mounted) _toast(context, _errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text.verbatim(_error!, textAlign: TextAlign.center)));
    }
    final all = _users;
    if (all == null) return const FlashingLogo();
    final me = _sb.auth.currentUser?.id;
    final users = all
        .where((u) => _name(u).toLowerCase().contains(_q) ||
            (u['username'] as String? ?? '').toLowerCase().contains(_q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr(context, 'Search people'),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i];
                final mine = u['user_id'] == me;
                final role = u['role'] as String;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AdminToolsPage._blue,
                    child: Text.verbatim(
                        _name(u).isEmpty ? '?' : _name(u)[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text.verbatim(_name(u) + (mine ? ' (you)' : '')),
                  subtitle: Text.verbatim('@${u['username']} · $role'),
                  trailing: mine
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (v) =>
                              v == 'delete' ? _delete(u) : _setRole(u, v),
                          itemBuilder: (_) => [
                            for (final r in const ['member', 'teacher', 'admin'])
                              if (r != role)
                                PopupMenuItem(
                                    value: r,
                                    child: Text.verbatim(
                                        '${tr(context, 'Make')} $r')),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete account')),
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- access

class _AccessTab extends StatefulWidget {
  const _AccessTab();

  @override
  State<_AccessTab> createState() => _AccessTabState();
}

class _AccessTabState extends State<_AccessTab> {
  List<Map<String, dynamic>>? _rows;

  static const _labels = {
    Feature.attendance: 'Attendance',
    Feature.timedConsole: 'Console',
    Feature.chat: 'Chat',
    Feature.calendarEdit: 'Edit calendar',
    Feature.announce: 'Post announcements',
    Feature.teacherReview: 'Approve teachers',
    Feature.contentEdit: 'Edit guidelines and contacts',
    Feature.mapEdit: 'Edit evacuation maps',
    Feature.auditLog: 'See the audit log',
    Feature.emergencyAlert: 'Send emergency alerts',
  };
  static const _roles = {1: 'Everyone', 2: 'Teachers and admins', 3: 'Admins only'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _sb.from('feature_access').select().order('feature');
      if (mounted) {
        setState(() =>
            _rows = [for (final r in rows) Map<String, dynamic>.from(r)]);
      }
    } catch (e) {
      if (mounted) _toast(context, _errorMessage(e));
    }
  }

  Future<void> _set(String feature, int rank) async {
    try {
      await _sb.rpc('admin_set_feature_rank',
          params: {'p_feature': feature, 'p_rank': rank});
      await _load();
      if (mounted) {
        // refresh this device's own permissions too
        context.read<AccountCubit>().load();
      }
    } catch (e) {
      if (mounted) _toast(context, _errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null) return const FlashingLogo();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Choose who can use each feature.',
              style: TextStyle(color: Colors.grey)),
        ),
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(_labels[r['feature']] ?? r['feature'] as String,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                          fontFamily: 'Geist')),
                ),
                DropdownButton<int>(
                  value: (r['min_rank'] as int).clamp(1, 3),
                  underline: const SizedBox.shrink(),
                  dropdownColor: AppColors.card(context),
                  items: [
                    for (final e in _roles.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) {
                    if (v != null && v != r['min_rank']) {
                      _set(r['feature'] as String, v);
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- data

class _DataTab extends StatefulWidget {
  const _DataTab();

  @override
  State<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<_DataTab> {
  Map<String, dynamic>? _status;
  bool _busy = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _sb.rpc('retention_status');
      if (mounted) setState(() => _status = Map<String, dynamic>.from(s as Map));
    } catch (e) {
      if (mounted) _toast(context, _errorMessage(e));
    }
  }

  Future<void> _purge() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete old data now?'),
        content: const Text(
            'Drills, attendance reports, emergency alerts and audit entries older than 30 days are deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final r = Map<String, dynamic>.from(
          await _sb.rpc('purge_old_data', params: {'p_days': 30}) as Map);
      _result = '${r['reports'] ?? 0} reports, ${r['drills'] ?? 0} drills, '
          '${r['alerts'] ?? 0} alerts, ${r['audit'] ?? 0} audit entries deleted.';
      await _load();
    } catch (e) {
      if (mounted) _toast(context, _errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final scheduled = s?['scheduled'] == true;
    final last = s?['last_run'] as String?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_delete, color: AdminToolsPage._blue),
                const SizedBox(width: 10),
                Text('30-day clean-up',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                        fontFamily: 'Geist')),
              ]),
              const SizedBox(height: 10),
              const Text(
                  'Drills, attendance reports, emergency alerts and the audit log are deleted automatically once they are 30 days old.'),
              const SizedBox(height: 10),
              if (s != null)
                Text.verbatim(scheduled
                    ? tr(context, 'Automatic daily clean-up is on.')
                    : tr(context,
                        'Automatic clean-up is NOT set up (enable pg_cron in Supabase). Use the button below.')),
              if (last != null)
                Text.verbatim(
                    '${tr(context, 'Last run')}: ${formatStamp(DateTime.parse(last).toLocal())}'),
              if (_result != null) ...[
                const SizedBox(height: 8),
                Text.verbatim(_result!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _busy ? null : _purge,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Delete old data now'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
