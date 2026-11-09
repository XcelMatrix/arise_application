import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/components/access_gate.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/cubits/drill/drill_cubit.dart';
import 'package:arise_application/models/attendance_models.dart';
import 'package:arise_application/pages/home_page.dart';
import 'package:arise_application/pages/profile_page.dart';

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

  @override
  void initState() {
    super.initState();
    context.read<DrillCubit>().load();
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

  @override
  Widget build(BuildContext context) => AccessGate(
        feature: Feature.timedConsole,
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
        title: const Text("Timed Console"),
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
                color: const Color(0xFFE4F2F9),
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
                          tooltip: 'Clear console',
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

              // console
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF1E1E1E),
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
                            padding: const EdgeInsets.all(10),
                            itemCount: state.log.length,
                            itemBuilder: (context, i) {
                              final e = state.log[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text.rich(
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
                                          text: e.message,
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
