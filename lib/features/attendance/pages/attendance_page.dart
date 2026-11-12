import 'package:flutter/material.dart' hide Text;
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

  TextStyle _head(BuildContext context) => TextStyle(
      fontWeight: FontWeight.bold,
      fontFamily: 'Geist',
      color: AppColors.body(context));
  static const _cell = TextStyle(fontFamily: 'Geist', fontSize: 14);

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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // saved class lists
          FloatingActionButton(
            heroTag: 'fab_class_lists',
            tooltip: tr(context, 'Class lists'),
            backgroundColor: _blue,
            onPressed: () => Navigator.push(context, ClassListsPage.route()),
            child: const Icon(Icons.groups, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'fab_add_attendance',
            backgroundColor: _blue,
            onPressed: _add,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Attendance',
                style: TextStyle(color: Colors.white, fontFamily: 'Geist')),
          ),
        ],
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
                    Expanded(
                      child: Text('Attendance Records',
                          style: TextStyle(
                              fontSize: 20,
                              color: AppColors.body(context),
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
                          : const Icon(Icons.refresh),
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
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 96),
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                showCheckboxColumn: false,
                                columnSpacing: 28,
                                headingTextStyle: _head(context),
                                dataTextStyle: _cell,
                                columns: const [
                                  DataColumn(label: Text('Timestamp')),
                                  DataColumn(label: Text('Grade & Section')),
                                  DataColumn(label: Text('Emergency')),
                                  DataColumn(label: Text('Site')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: [
                                  for (final r in state.mine)
                                    DataRow(
                                      onSelectChanged: (_) => Navigator.push(
                                          context,
                                          AttendanceReportPage.route(r.id)),
                                      cells: [
                                        DataCell(Text(formatStamp(r.eventTime))),
                                        DataCell(Text(r.label)),
                                        DataCell(Text(r.emergencyType)),
                                        DataCell(Text(r.site)),
                                        DataCell(Text(
                                          _statusText(r),
                                          style: TextStyle(
                                            fontFamily: 'Geist',
                                            fontWeight: FontWeight.bold,
                                            color: r.submitted
                                                ? const Color(0xFF2E7D32)
                                                : Colors.grey.shade700,
                                          ),
                                        )),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
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
