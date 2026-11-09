import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/components/access_gate.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/cubits/drill/drill_cubit.dart';
import 'package:arise_application/models/attendance_models.dart';
import 'package:arise_application/pages/attendance_report_page.dart';
import 'package:arise_application/pages/home_page.dart';
import 'package:arise_application/pages/profile_page.dart';
import 'package:arise_application/pages/report_form_dialog.dart';

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

  static const _head = TextStyle(
      fontWeight: FontWeight.bold, fontFamily: 'Geist', color: Colors.black87);
  static const _cell = TextStyle(fontFamily: 'Geist', fontSize: 14);

  String _statusText(AttendanceReport r) {
    if (r.students.isEmpty && !r.submitted) return 'No students';
    if (r.submitted) return 'Sent';
    return '${r.marked}/${r.students.length} set';
  }

  @override
  Widget build(BuildContext context) => AccessGate(
        feature: Feature.attendance,
        child: Builder(builder: _page),
      );

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset("assets/icons/icon_white.png", width: 48, height: 48),
          color: Colors.white,
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const HomePage())),
        ),
        backgroundColor: _blue,
        title: const Text("Attendance"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person),
            iconSize: 36,
            color: const Color(0xFFACACAC),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              fixedSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfilePage())),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        onPressed: _add,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Attendance',
            style: TextStyle(color: Colors.white, fontFamily: 'Geist')),
      ),
      body: BlocBuilder<DrillCubit, DrillState>(
        builder: (context, state) {
          if (!state.loaded) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }
          return Column(
            children: [
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
                    const Expanded(
                      child: Text('Attendance Records',
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.black87,
                              fontFamily: 'Geist')),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('School year ${DrillCubit.schoolYear}',
                      style: const TextStyle(
                          color: Colors.grey, fontFamily: 'Geist')),
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
                                headingTextStyle: _head,
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
