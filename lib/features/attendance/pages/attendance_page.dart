import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/theme/stat_colors.dart';
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:arise_application/features/console/pages/timed_console_page.dart';
import 'package:arise_application/features/resources/pages/disaster_resources_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/attendance/pages/class_lists_page.dart';
import 'package:arise_application/features/account/widgets/access_gate.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/attendance/pages/attendance_report_page.dart';
import 'package:arise_application/features/home/pages/home_page.dart';
import 'package:arise_application/features/attendance/widgets/report_form_dialog.dart';
import 'package:arise_application/features/attendance/widgets/report_actions.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/features/resources/data/guideline_icons.dart';

/// Table of the user's attendance reports. Tap a row to open it, tap
/// "Add Attendance" to create a new one.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const AttendancePage());
  }

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const _blue = Color(0xFF3C6E87);
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    context.read<DrillCubit>().load();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refresh() async {
    final cubit = context.read<DrillCubit>();
    setState(() => _refreshing = true);
    try {
      await cubit.refresh();
    } catch (e) {
      _toast(DrillCubit.describe(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _add() async {
    final cubit = context.read<DrillCubit>();
    final input = await showDialog<NewReportInput>(
      context: context,
      builder: (_) => ReportFormDialog(existing: cubit.state.mine),
    );
    if (input == null || !mounted) return;

    try {
      final id = await cubit.createReport(
        grade: input.grade,
        section: input.section,
        site: input.site,
        emergencyType: input.emergencyType,
        eventTime: input.eventTime,
        copyFromReportId: input.copyFromId,
      );
      if (!mounted) return;
      Navigator.push(context, AttendanceReportPage.route(id));
    } catch (e) {
      _toast('Could not create attendance: ${DrillCubit.describe(e)}');
    }
  }

  String _statusText(AttendanceReport r) {
    if (r.students.isEmpty && !r.submitted) return 'No students';
    if (r.submitted) return 'Sent';
    return '${r.marked}/${r.students.length} set';
  }

  int _currentIndex = 1;

  /// True if the signed-in account's role allows this feature.
  bool _allowed(String feature) =>
      context.read<AccountCubit>().state.canAccess(feature);

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Your account level doesn't have access to this."),
    ));
  }

  /// Bottom-bar positions this account can use (student-locked ones hidden).
  List<int> _visibleNav(BuildContext context, {bool listen = true}) {
    final a = listen
        ? context.watch<AccountCubit>().state
        : context.read<AccountCubit>().state;
    return [
      0,
      if (a.canAccess(Feature.attendance)) 1,
      if (a.canAccess(Feature.timedConsole)) 2,
      3,
    ];
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1:
        break;
      case 2:
        if (!_allowed(Feature.timedConsole)) return _denied();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TimedConsolePage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DisasterResourcesPage()),
        );
        break;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) => AccessGate(
        feature: Feature.attendance,
        child: Builder(builder: _page),
      );

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        leading: const BackOrLogo(),
        backgroundColor: _blue,
        title: const Text("Attendance"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: <Widget>[
          const ProfileMenuButton()
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _visibleNav(context).indexOf(_currentIndex),
        onTap: (i) => _onItemTapped(_visibleNav(context, listen: false)[i]),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF3C6E87),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFFACACAC),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Geist',
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 11,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: tr(context, 'Home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: tr(context, 'Attendance'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terminal),
            label: tr(context, 'Console'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: tr(context, 'Resources'),
          ),
        ]
            .asMap()
            .entries
            .where((e) => _visibleNav(context).contains(e.key))
            .map((e) => e.value)
            .toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_attendance',
        backgroundColor: _blue,
        onPressed: _add,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Attendance',
            style: TextStyle(color: Colors.white, fontFamily: 'Geist')),
      ),
      body: BlocBuilder<DrillCubit, DrillState>(
        builder: (context, state) {
          if (!state.loaded) {
            return const FlashingLogo();
          }
          return Column(
            children: [
              if (state.pending > 0)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEF6C00),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${state.pending} ${tr(context, 'change(s) saved on this phone. They are sent when you are back online.')}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Geist'),
                  ),
                ),
              if (state.drillActive)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFB3261E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'DRILL IN PROGRESS  •  ${DrillCubit.formatDuration(state.elapsed)}  •  '
                    '${state.reportedCount}/${state.expectedCount} reports sent',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Geist'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    // saved class lists, on the left of the title
                    IconButton(
                      tooltip: tr(context, 'Class Lists'),
                      onPressed: () =>
                          Navigator.push(context, ClassListsPage.route()),
                      icon: const Icon(Icons.groups, color: _blue),
                    ),
                    Expanded(
                      child: Text('Attendance Records',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              color: _blue,
                              fontFamily: 'Geist')),
                    ),
                    IconButton(
                      tooltip: tr(context, 'Refresh'),
                      onPressed: _refreshing ? null : _refresh,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _blue))
                          : const Icon(Icons.refresh, color: _blue),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.mine.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No attendance yet.\nTap "Add Attendance" to create one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _blue, fontFamily: 'Geist', fontSize: 14),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: _blue,
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          itemCount: state.mine.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final r = state.mine[i];
                            return _RecordCard(
                              report: r,
                              status: _statusText(r),
                              onTap: () => Navigator.push(
                                  context, AttendanceReportPage.route(r.id)),
                              onAction: (a) {
                                switch (a) {
                                  case 'import':
                                    ReportActions.importList(context, r);
                                  case 'save':
                                    ReportActions.saveAsList(context, r);
                                  case 'edit':
                                    ReportActions.edit(context, r);
                                  case 'delete':
                                    ReportActions.delete(context, r);
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}


/// One attendance record as a card: the disaster's icon, the class, when and
/// where, and the Present / Absent / Missing / Injured counts.
class _RecordCard extends StatelessWidget {
  const _RecordCard(
      {required this.report,
      required this.status,
      required this.onTap,
      required this.onAction});

  final AttendanceReport report;
  final String status;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  static const _blue = Color(0xFF3C6E87);

  IconData _icon(BuildContext context) {
    final type = report.emergencyType;
    if (type != 'Other' && emergencyTypes.contains(type)) {
      for (final g in context.watch<GuidelinesCubit>().state.rows) {
        if ('${g['title']}'.toLowerCase() == type.toLowerCase()) {
          final spec = g['icon'] as String?;
          if (spec != null &&
              spec.startsWith('i:') &&
              GuidelineIcons.map.containsKey(spec.substring(2))) {
            return GuidelineIcons.map[spec.substring(2)]!;
          }
        }
      }
    }
    return Icons.warning_amber;
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    final sent = r.submitted;
    final pill = sent ? const Color(0xFF2E7D32) : _blue;
    final pillPal = StatColors.of(context, pill);
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icon(context), color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.verbatim(r.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _blue,
                                fontFamily: 'Geist')),
                        const SizedBox(height: 2),
                        Text(r.emergencyType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                color: _blue,
                                fontFamily: 'Geist')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pillPal.box,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: pillPal.text),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: pillPal.text,
                            fontFamily: 'Geist')),
                  ),
                  // same menu as inside an attendance, without "Mark all present"
                  PopupMenuButton<String>(
                    iconColor: _blue,
                    padding: EdgeInsets.zero,
                    tooltip: tr(context, 'More'),
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'import', child: Text('Add from class list')),
                      PopupMenuItem(
                          value: 'save',
                          enabled: report.students.isNotEmpty,
                          child: const Text('Save as class list')),
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit details')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete attendance')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _line(Icons.schedule, formatStamp(r.eventTime)),
              if (r.site.isNotEmpty) _line(Icons.place, r.site),
              if (r.students.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final s in AttendanceStatus.values) ...[
                      Expanded(child: _count(context, s)),
                      if (s != AttendanceStatus.values.last)
                        const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: _blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text.verbatim(text,
                style: const TextStyle(
                    fontSize: 13, color: _blue, fontFamily: 'Geist')),
          ),
        ]),
      );

  Widget _count(BuildContext context, AttendanceStatus s) {
    final n = report.students.where((x) => x.status == s).length;
    final pal = StatColors.of(context, s.color);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: pal.box,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text.verbatim('$n',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: pal.text,
                fontFamily: 'Geist')),
        Text(s.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10, color: pal.text, fontFamily: 'Geist')),
      ]),
    );
  }
}
