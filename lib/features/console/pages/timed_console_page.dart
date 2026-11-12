import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:flutter/material.dart' as m show Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:arise_application/features/attendance/pages/attendance_page.dart';
import 'package:arise_application/features/resources/pages/disaster_resources_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/widgets/access_gate.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/features/home/pages/home_page.dart';
import 'package:arise_application/features/console/cubit/audit_cubit.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/features/console/pages/drill_history_page.dart';

class TimedConsolePage extends StatefulWidget {
  const TimedConsolePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const TimedConsolePage());
  }

  @override
  State<TimedConsolePage> createState() => _TimedConsolePageState();
}

class _TimedConsolePageState extends State<TimedConsolePage> {
  static const _blue = Color(0xFF3C6E87);
  final _scroll = ScrollController();
  int _tab = 0; // 0 console, 1 audit log, 2 alert history

  @override
  void initState() {
    super.initState();
    context.read<DrillCubit>().load();
    context.read<AuditCubit>().load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  static String _stamp(DateTime t) => '[${DrillCubit.formatClock(t)}]';

  static Color _color(ConsoleLevel l) {
    switch (l) {
      case ConsoleLevel.success:
        return const Color(0xFF55FF55); // bright green
      case ConsoleLevel.warning:
        return const Color(0xFFFFAA00); // gold
      case ConsoleLevel.alert:
        return const Color(0xFFFF5555); // red
      case ConsoleLevel.system:
        return const Color(0xFF55FFFF); // aqua
      case ConsoleLevel.info:
        return const Color(0xFFAAAAAA); // grey
    }
  }

  static String _tag(ConsoleLevel l) {
    switch (l) {
      case ConsoleLevel.success:
        return ''; // no tag for normal lines
      case ConsoleLevel.warning:
        return 'WARN';
      case ConsoleLevel.alert:
        return 'ALERT';
      case ConsoleLevel.system:
        return 'SYSTEM';
      case ConsoleLevel.info:
        return '';
    }
  }

  int _currentIndex = 2;

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
        if (!_allowed(Feature.attendance)) return _denied();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AttendancePage()),
        );
        break;
      case 2:
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
        feature: Feature.timedConsole,
        child: Builder(builder: _page),
      );

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        leading: const BackOrLogo(),
        backgroundColor: _blue,
        title: const Text("Console"),
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
      body: BlocConsumer<DrillCubit, DrillState>(
        listenWhen: (a, b) => a.log.length != b.log.length,
        listener: (_, __) => _scrollToBottom(),
        builder: (context, state) {
          final cubit = context.read<DrillCubit>();
          final hasDrill = state.drillId != null &&
              (state.drillActive || state.drillComplete);

          return Column(
            children: [
              // status / controls bar
              Container(
                width: double.infinity,
                color: AppColors.soft(context),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.drillActive
                                    ? 'DRILL ACTIVE'
                                    : state.drillComplete
                                        ? 'EVACUATION COMPLETE'
                                        : 'STANDBY',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Geist',
                                  color: state.drillActive
                                      ? const Color(0xFFB3261E)
                                      : state.drillComplete
                                          ? Colors.green.shade700
                                          : _blue,
                                ),
                              ),
                              Text(
                                hasDrill
                                    ? '${DrillCubit.formatDuration(state.elapsed)}  •  '
                                        '${state.reportedCount}/${state.expectedCount} reports sent'
                                    : 'No drill running',
                                style: const TextStyle(
                                    color: _blue,
                                    fontFamily: 'Geist',
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (state.drillActive)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB3261E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: cubit.cancelDrill,
                            child: const Text('Cancel'),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: cubit.startDrill,
                            child: const Text('Start drill'),
                          ),
                        IconButton(
                          tooltip: tr(context, 'Drill history'),
                          icon: const Icon(Icons.history, color: _blue),
                          onPressed: () =>
                              Navigator.push(context, DrillHistoryPage.route()),
                        ),
                        IconButton(
                          tooltip: tr(context, 'Clear console'),
                          icon: const Icon(Icons.delete_sweep, color: _blue),
                          onPressed: cubit.clearConsole,
                        ),
                      ],
                    ),

                    // running totals for the drill
                    if (hasDrill)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in AttendanceStatus.values)
                              _TotalChip(
                                color: s.color,
                                text: '${s.label} ${state.totalOf(s)}',
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Console / Audit log switch
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _blue,
                      selectedForegroundColor: Colors.white,
                    ),
                    segments: const [
                      ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.terminal),
                          label: Text('Console')),
                      ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.fact_check),
                          label: Text('Audit log')),
                      ButtonSegment(
                          value: 2,
                          icon: Icon(Icons.warning_amber_rounded),
                          label: Text('Alerts')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                ),
              ),

              // console
              Expanded(
                child: _tab == 1
                    ? const _AuditView()
                    : _tab == 2
                        ? const _AlertHistoryView()
                        : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: state.log.isEmpty
                      ? const Center(
                          child: Text('> waiting for reports...',
                              style: TextStyle(
                                  color: Color(0xFF777777),
                                  fontFamily: 'monospace')))
                      : Scrollbar(
                          controller: _scroll,
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(14),
                            itemCount: state.log.length,
                            itemBuilder: (context, i) {
                              final e = state.log[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: m.Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12.5,
                                        height: 1.3),
                                    children: [
                                      TextSpan(
                                          text: '${_stamp(e.time)} ',
                                          style: const TextStyle(
                                              color: Color(0xFF777777))),
                                      if (_tag(e.level).isNotEmpty)
                                        TextSpan(
                                            text: '[${_tag(e.level)}]: ',
                                            style: TextStyle(
                                                color: _color(e.level))),
                                      TextSpan(
                                          text: tr(context, e.message),
                                          style: TextStyle(
                                              color: _color(e.level),
                                              fontWeight: e.message
                                                      .startsWith('EVACUATION')
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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

class _TotalChip extends StatelessWidget {
  const _TotalChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamily: 'Geist',
        ),
      ),
    );
  }
}

/// Audit log: who did what, newest first, in the same console style.
class _AuditView extends StatelessWidget {
  const _AuditView();

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AuditCubit>().state;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: !a.loaded
          ? const Center(child: CircularProgressIndicator())
          : a.entries.isEmpty
              ? const Center(
                  child: Text('> no activity recorded yet',
                      style: TextStyle(
                          color: Color(0xFF777777), fontFamily: 'monospace')))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: a.entries.length + (a.offline ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (a.offline && i == 0) {
                      return const Text('> offline: showing saved log',
                          style: TextStyle(
                              color: Color(0xFFFFAA00),
                              fontFamily: 'monospace',
                              fontSize: 12.5));
                    }
                    final e = a.entries[i - (a.offline ? 1 : 0)];
                    final urgent = e.action.startsWith('EMERGENCY');
                    final c = urgent
                        ? const Color(0xFFFF5555)
                        : e.action.contains('deleted') ||
                                e.action.contains('cancelled') ||
                                e.action.contains('declined')
                            ? const Color(0xFFFFAA00)
                            : const Color(0xFF55FF55);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: m.Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              height: 1.3),
                          children: [
                            TextSpan(
                                text:
                                    '[${e.time.month}/${e.time.day} ${DrillCubit.formatClock(e.time)}] ',
                                style:
                                    const TextStyle(color: Color(0xFF777777))),
                            TextSpan(
                                text: tr(context, e.action),
                                style: TextStyle(color: c)),
                            if (e.detail != null)
                              TextSpan(
                                  text: ': ${e.detail}',
                                  style: const TextStyle(
                                      color: Color(0xFFDDDDDD))),
                            TextSpan(
                                text: '  by ${e.actor}',
                                style:
                                    const TextStyle(color: Color(0xFF888888))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Every emergency alert that was sent, newest first.
class _AlertHistoryView extends StatelessWidget {
  const _AlertHistoryView();

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AlertLogCubit>().state;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: !a.loaded
          ? const FlashingLogo(color: Colors.white)
          : a.rows.isEmpty
              ? const Center(
                  child: Text('> no emergency alerts sent',
                      style: TextStyle(
                          color: Color(0xFF777777), fontFamily: 'monospace')))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: a.rows.length + (a.offline ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (a.offline && i == 0) {
                      return const Text('> offline: showing saved history',
                          style: TextStyle(
                              color: Color(0xFFFFAA00),
                              fontFamily: 'monospace',
                              fontSize: 12.5));
                    }
                    final r = a.rows[i - (a.offline ? 1 : 0)];
                    final sent = DateTime.parse(r['created_at'] as String).toLocal();
                    final clearedRaw = r['cleared_at'] as String?;
                    final cleared =
                        clearedRaw == null ? null : DateTime.parse(clearedRaw).toLocal();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: m.Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12.5, height: 1.3),
                          children: [
                            TextSpan(
                                text:
                                    '[${sent.month}/${sent.day} ${DrillCubit.formatClock(sent)}] ',
                                style: const TextStyle(color: Color(0xFF777777))),
                            TextSpan(
                                text: '${(r['kind'] as String).toUpperCase()}: ',
                                style: const TextStyle(color: Color(0xFFFF5555))),
                            TextSpan(
                                text: '${r['message']}',
                                style: const TextStyle(color: Color(0xFFDDDDDD))),
                            TextSpan(
                                text: '  by ${(r['sender_name'] as String?) ?? 'Unknown'}',
                                style: const TextStyle(color: Color(0xFF888888))),
                            TextSpan(
                                text: cleared == null
                                    ? '  [ACTIVE]'
                                    : '  [all clear ${DrillCubit.formatClock(cleared)}]',
                                style: TextStyle(
                                    color: cleared == null
                                        ? const Color(0xFFFF5555)
                                        : const Color(0xFF55FF55))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
