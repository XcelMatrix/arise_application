import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/utils/time_format.dart';
import 'package:arise_application/features/admin/widgets/audit_text.dart';
import 'package:arise_application/features/console/cubit/audit_cubit.dart';
import 'package:arise_application/features/reports/services/audit_export.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';

const _filters = <(String, String, IconData, Color)>[
  ('all', 'All', Icons.list, Color(0xFF3C6E87)),
  ('role', 'Roles and access', Icons.manage_accounts, Color(0xFF6A1B9A)),
  ('deletion', 'Deletions', Icons.delete_outline, Color(0xFFE65100)),
  ('alert', 'Alerts', Icons.warning_amber_rounded, Color(0xFFB3261E)),
  ('drill', 'Drills', Icons.directions_run, Color(0xFF2E7D32)),
  ('other', 'Other', Icons.more_horiz, Color(0xFF546E7A)),
];

/// Who changed roles, deleted accounts, sent alerts and so on. Newest first.
/// Entries are shown in the language picked in Settings; alerts show the
/// message the sender wrote for that language.
class AuditLogView extends StatefulWidget {
  const AuditLogView({super.key});

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    context.read<AuditCubit>().load();
    context.read<AlertLogCubit>().load();
  }

  Future<void> _export(String kind, List<AuditEntry> shown,
      List<Map<String, dynamic>> alerts) async {
    try {
      if (kind == 'pdf') {
        await AuditExport.sharePdf(shown, alerts);
      } else {
        await AuditExport.shareCsv(shown, alerts);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text.verbatim('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final a = context.watch<AuditCubit>().state;
    final alerts = context.watch<AlertLogCubit>().state.rows;
    final shown = [
      for (final e in a.entries)
        if (_filter == 'all' || e.category == _filter) e,
    ];
    final meta = {for (final f in _filters) f.$1: f};

    return !a.loaded
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => context.read<AuditCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Who changed what, newest first.',
                          style: const TextStyle(color: Colors.grey)),
                    ),
                    PopupMenuButton<String>(
                      tooltip: tr(context, 'Export'),
                      icon: const Icon(Icons.ios_share),
                      onSelected: (v) => _export(v, shown, alerts),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                        PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
                      ],
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(f.$3,
                                size: 16,
                                color: _filter == f.$1 ? Colors.white : f.$4),
                            label: Text(f.$2),
                            selected: _filter == f.$1,
                            selectedColor: f.$4,
                            labelStyle: TextStyle(
                                color: _filter == f.$1 ? Colors.white : null,
                                fontFamily: 'Geist'),
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = f.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (a.offline)
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
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                        child: Text('Nothing recorded yet.',
                            style: const TextStyle(color: Colors.grey))),
                  ),
                for (final e in shown)
                  Builder(builder: (context) {
                    final f = meta[e.category] ?? meta['other']!;
                    final detail = AuditText.detail(e, alerts);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: f.$4,
                            child: Icon(f.$3, size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.verbatim(AuditText.action(e),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.text(context),
                                        fontFamily: 'Geist')),
                                if (detail != null)
                                  Text.verbatim(detail,
                                      style: TextStyle(
                                          color: AppColors.text(context))),
                                const SizedBox(height: 2),
                                Text.verbatim(
                                    '${e.actor}  •  ${Tr.months[e.time.month - 1]} ${e.time.day}, ${TimeFormat.clock(e.time)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
  }
}
