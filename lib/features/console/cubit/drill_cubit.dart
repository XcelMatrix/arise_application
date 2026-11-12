import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';
import 'package:arise_application/core/services/local_cache.dart';

class DrillState {
  /// The signed-in user's own reports, with their students.
  final List<AttendanceReport> mine;

  /// Every report (counts only), kept live by realtime. Feeds the console.
  final List<AttendanceReport> feed;

  final List<ConsoleEntry> log;
  final String? drillId;
  final bool drillActive;
  final bool drillComplete;
  final DateTime? drillStart;
  final Duration elapsed;
  final bool loaded;
  final String? myUserId;

  /// Changes made without a connection, waiting to be sent.
  final int pending;

  /// true when `mine` is the copy saved on this phone.
  final bool offline;

  const DrillState({
    this.mine = const [],
    this.feed = const [],
    this.log = const [],
    this.drillId,
    this.drillActive = false,
    this.drillComplete = false,
    this.drillStart,
    this.elapsed = Duration.zero,
    this.loaded = false,
    this.myUserId,
    this.pending = 0,
    this.offline = false,
  });

  /// Reports that belong to the current drill.
  List<AttendanceReport> get drillReports {
    final id = drillId;
    if (id == null) return const [];
    return feed.where((r) => r.drillId == id).toList();
  }

  int get expectedCount => drillReports.length;
  int get reportedCount => drillReports.where((r) => r.submitted).length;

  int totalOf(AttendanceStatus s) => drillReports
      .where((r) => r.submitted)
      .fold<int>(0, (sum, r) => sum + r.countFor(s));

  DrillState copyWith({
    List<AttendanceReport>? mine,
    List<AttendanceReport>? feed,
    List<ConsoleEntry>? log,
    String? drillId,
    bool? drillActive,
    bool? drillComplete,
    DateTime? drillStart,
    Duration? elapsed,
    bool? loaded,
    String? myUserId,
    int? pending,
    bool? offline,
    bool clearDrill = false,
  }) =>
      DrillState(
        mine: mine ?? this.mine,
        feed: feed ?? this.feed,
        log: log ?? this.log,
        drillId: clearDrill ? null : (drillId ?? this.drillId),
        drillActive: drillActive ?? this.drillActive,
        drillComplete: drillComplete ?? this.drillComplete,
        drillStart: clearDrill ? null : (drillStart ?? this.drillStart),
        elapsed: elapsed ?? this.elapsed,
        loaded: loaded ?? this.loaded,
        myUserId: myUserId ?? this.myUserId,
        pending: pending ?? this.pending,
        offline: offline ?? this.offline,
      );
}

/// Thrown inside the cubit when changes saved offline could not be sent yet.
class SocketLikeOffline implements Exception {
  const SocketLikeOffline();
}

/// Shared by the Attendance pages and the Timed Console.
class DrillCubit extends Cubit<DrillState> {
  DrillCubit() : super(const DrillState());

  final _sb = Supabase.instance.client;

  Timer? _ticker;
  StreamSubscription<List<Map<String, dynamic>>>? _drillSub;
  StreamSubscription<List<Map<String, dynamic>>>? _feedSub;

  /// Keys of report lines already written to the console.
  final Set<String> _printed = {};
  bool _feedSeen = false;
  Map<String, dynamic>? _completeRow;
  bool _completePrinted = false;

  /// A drill left "active" longer than this is treated as abandoned.
  static const _staleAfter = Duration(hours: 6);

  /// School year, e.g. "2026-2027". A new one starts in June.
  static String get schoolYear {
    final now = DateTime.now();
    final start = now.month >= 6 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }

  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  /// Clock time for console lines, e.g. "02:45:12 PM".
  static String formatClock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = t.hour < 12 ? 'AM' : 'PM';
    return '${two(h)}:${two(t.minute)}:${two(t.second)} $suffix';
  }

  /// A length of time in words, e.g. "1 min 12 sec".
  static String formatDurationWords(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final parts = <String>[
      if (h > 0) '$h hr',
      if (m > 0) '$m min',
      if (s > 0 || (h == 0 && m == 0)) '$s sec',
    ];
    return parts.join(' ');
  }

  /// Readable text for an error (database messages come through as-is).
  static String describe(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  // ---------- loading ----------

  /// Safe to call repeatedly: reloads my reports, subscribes only once.
  Future<void> load() async {
    final myId = _sb.auth.currentUser?.id;
    if (myId == null) return;

    // a different account signed in on this device
    if (state.myUserId != null && state.myUserId != myId) {
      await _reset();
    }

    final firstLoad = !state.loaded;
    emit(state.copyWith(myUserId: myId));

    await flushOutbox();
    try {
      await _loadMine();
    } catch (e) {
      _print('Could not load attendance reports: ${describe(e)}',
          ConsoleLevel.alert);
    }

    if (!firstLoad) return;
    emit(state.copyWith(loaded: true));
    _print('Timed Console ready. School year $schoolYear.', ConsoleLevel.system);
    _subscribe();
  }

  Future<void> _reset() async {
    _ticker?.cancel();
    await _drillSub?.cancel();
    await _feedSub?.cancel();
    _drillSub = null;
    _feedSub = null;
    _printed.clear();
    _feedSeen = false;
    _completeRow = null;
    _completePrinted = false;
    if (!isClosed) emit(const DrillState());
  }

  Future<void> _loadMine() async {
    final myId = _sb.auth.currentUser?.id;
    if (myId == null) return;

    List<Map<String, dynamic>> rows;
    var offline = false;
    try {
      final data = await _sb
          .from('attendance_reports')
          .select('*, report_students(id, name, status, created_at)')
          .eq('owner_id', myId)
          .eq('school_year', schoolYear)
          .order('event_time', ascending: false);
      rows = [for (final r in data) Map<String, dynamic>.from(r)];
      await LocalCache.save(_mineKey, rows);
    } catch (e) {
      if (!_isOffline(e)) rethrow;
      final cached = await LocalCache.readRows(_mineKey);
      if (cached == null) rethrow;
      rows = cached;
      offline = true;
    }

    var reports = [for (final row in rows) AttendanceReport.fromRow(row)];
    final queue = await _readOutbox();
    if (queue.isNotEmpty) reports = _applyOps(reports, queue);
    if (isClosed) return;
    emit(state.copyWith(mine: reports, pending: queue.length, offline: offline));
  }

  // ---------- offline: changes saved on the phone, sent later ----------
  //
  // Marking students and sending a report keep working without a connection.
  // The changes are kept in a list on the phone and sent, in order, as soon
  // as the connection is back. (Creating a new report or adding students to
  // one needs a connection.)

  String get _mineKey => 'attendance_mine_${_sb.auth.currentUser?.id}';
  String get _outboxKey => 'attendance_outbox_${_sb.auth.currentUser?.id}';

  /// A rejected request (Postgrest / auth) is not "offline"; anything else
  /// (no network, timeout) is.
  static bool _isOffline(Object e) =>
      e is! PostgrestException && e is! AuthException;

  Future<List<Map<String, dynamic>>> _readOutbox() async =>
      await LocalCache.readRows(_outboxKey) ?? [];

  Future<void> _queue(Map<String, dynamic> op) async {
    final q = await _readOutbox();
    q.add(op);
    await LocalCache.save(_outboxKey, q);
    if (!isClosed) emit(state.copyWith(pending: q.length, offline: true));
  }

  List<AttendanceReport> _applyOps(
      List<AttendanceReport> reports, List<Map<String, dynamic>> ops) {
    for (final op in ops) {
      final status = AttendanceStatus.parse(op['status'] as String?);
      if (status == null) continue;
      if (op['op'] == 'status') {
        reports = [
          for (final r in reports)
            r.copyWith(students: [
              for (final s in r.students)
                s.id == op['student'] ? s.copyWith(status: status) : s,
            ]),
        ];
      } else if (op['op'] == 'all') {
        reports = [
          for (final r in reports)
            r.id == op['report']
                ? r.copyWith(students: [
                    for (final s in r.students) s.copyWith(status: status),
                  ])
                : r,
        ];
      }
    }
    return reports;
  }

  bool _flushing = false;

  /// Sends the changes saved while offline. Stops at the first one that
  /// still can't be sent (still offline) and tries again later.
  Future<void> flushOutbox() async {
    if (_flushing || _sb.auth.currentUser == null) return;
    _flushing = true;
    try {
      var q = await _readOutbox();
      if (q.isEmpty) return;
      var sent = 0;
      while (q.isNotEmpty) {
        final op = q.first;
        try {
          switch (op['op']) {
            case 'status':
              await _sb
                  .from('report_students')
                  .update({'status': op['status']}).eq('id', op['student']);
              break;
            case 'all':
              await _sb
                  .from('report_students')
                  .update({'status': op['status']}).eq('report_id', op['report']);
              break;
            case 'submit':
              await _sb.rpc('submit_attendance_report',
                  params: {'p_report_id': op['report']});
              break;
          }
          sent++;
        } catch (e) {
          if (_isOffline(e)) break; // still no connection: keep it
          // the server refused it (e.g. the report was deleted): drop it
        }
        q = q.sublist(1);
        await LocalCache.save(_outboxKey, q);
      }
      if (!isClosed) emit(state.copyWith(pending: q.length));
      if (sent > 0) {
        _print('Sent $sent change(s) saved while offline.', ConsoleLevel.system);
        if (q.isEmpty) {
          try {
            await _loadMine();
          } catch (_) {}
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// Pull-to-refresh on the attendance page.
  Future<void> refresh() => _loadMine();

  void _subscribe() {
    _drillSub = _sb
        .from('drills')
        .stream(primaryKey: ['id'])
        .order('started_at', ascending: false)
        .limit(1)
        .listen(_onDrill, onError: (_) {
      _print('Lost connection to the drill feed.', ConsoleLevel.warning);
    });

    _feedSub = _sb
        .from('attendance_reports')
        .stream(primaryKey: ['id'])
        .eq('school_year', schoolYear)
        .order('created_at', ascending: false)
        .limit(300)
        .listen(_onFeed, onError: (_) {
      _print('Lost connection to the report feed.', ConsoleLevel.warning);
    });
  }

  // ---------- console ----------

  // every new console line is also announced here (the Inbox listens)
  final _entries = StreamController<ConsoleEntry>.broadcast();
  Stream<ConsoleEntry> get entries => _entries.stream;

  void _print(String message,
      [ConsoleLevel level = ConsoleLevel.info, DateTime? at]) {
    if (isClosed) return;
    final entry =
        ConsoleEntry(time: at ?? DateTime.now(), message: message, level: level);
    emit(state.copyWith(log: [...state.log, entry]));
    if (!_entries.isClosed) _entries.add(entry);
  }

  void clearConsole() => emit(state.copyWith(log: const []));

  // ---------- my reports ----------

  AttendanceReport? _report(String id) {
    for (final r in state.mine) {
      if (r.id == id) return r;
    }
    return null;
  }

  void _replaceReport(
      String id, AttendanceReport Function(AttendanceReport) fn) {
    emit(state.copyWith(
      mine: [for (final r in state.mine) r.id == id ? fn(r) : r],
    ));
  }

  /// Creates a report (the timestamp, grade, section, site and emergency
  /// type are fixed here; every student added later inherits grade/section).
  /// Optionally copies the students of an earlier report.
  Future<String> createReport({
    required String grade,
    required String section,
    required String site,
    required String emergencyType,
    required DateTime eventTime,
    String? copyFromReportId,
  }) async {
    final row = await _sb
        .from('attendance_reports')
        .insert({
          'grade': grade,
          'section': section,
          'evacuation_site': site,
          'emergency_type': emergencyType,
          'event_time': eventTime.toUtc().toIso8601String(),
          'school_year': schoolYear,
        })
        .select()
        .single();

    var students = <Student>[];
    final source =
        copyFromReportId == null ? null : _report(copyFromReportId);
    if (source != null && source.students.isNotEmpty) {
      final inserted = await _sb
          .from('report_students')
          .insert([
            for (final s in source.students)
              {'report_id': row['id'], 'name': s.name},
          ])
          .select('id, name, status, created_at');
      students = [
        for (final r in inserted)
          Student.fromRow(Map<String, dynamic>.from(r)),
      ];
    }

    final report = AttendanceReport.fromRow(Map<String, dynamic>.from(row))
        .copyWith(students: students);
    final all = [...state.mine, report]
      ..sort((a, b) => b.eventTime.compareTo(a.eventTime));
    emit(state.copyWith(mine: all));
    return report.id;
  }

  Future<void> deleteReport(String reportId) async {
    await _sb.from('attendance_reports').delete().eq('id', reportId);
    emit(state.copyWith(
      mine: state.mine.where((r) => r.id != reportId).toList(),
    ));
  }

  Future<void> addStudent(String reportId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final row = await _sb
        .from('report_students')
        .insert({'report_id': reportId, 'name': trimmed})
        .select('id, name, status, created_at')
        .single();
    final student = Student.fromRow(Map<String, dynamic>.from(row));
    _replaceReport(
      reportId,
      (r) => r.copyWith(students: [...r.students, student]),
    );
  }

  Future<void> removeStudent(String reportId, String studentId) async {
    await _sb.from('report_students').delete().eq('id', studentId);
    _replaceReport(
      reportId,
      (r) => r.copyWith(
        students: r.students.where((s) => s.id != studentId).toList(),
      ),
    );
  }

  /// Edit the report's timestamp, grade, section, site or emergency type.
  Future<void> updateReport(
    String reportId, {
    required String grade,
    required String section,
    required String site,
    required String emergencyType,
    required DateTime eventTime,
  }) async {
    final row = await _sb
        .from('attendance_reports')
        .update({
          'event_time': eventTime.toUtc().toIso8601String(),
          'grade': grade,
          'section': section,
          'evacuation_site': site,
          'emergency_type': emergencyType,
        })
        .eq('id', reportId)
        .select()
        .single();
    final updated =
        AttendanceReport.fromRow(Map<String, dynamic>.from(row));
    final all = [
      for (final r in state.mine)
        r.id == reportId ? updated.copyWith(students: r.students) : r,
    ]..sort((a, b) => b.eventTime.compareTo(a.eventTime));
    emit(state.copyWith(mine: all));
  }

  Future<void> renameStudent(
      String reportId, String studentId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _sb
        .from('report_students')
        .update({'name': trimmed}).eq('id', studentId);
    _replaceReport(
      reportId,
      (r) => r.copyWith(students: [
        for (final s in r.students)
          s.id == studentId ? s.copyWith(name: trimmed) : s,
      ]),
    );
  }

  /// Set one student's status. Returns true if that completed the report
  /// during a drill and it was sent to the console automatically.
  Future<bool> setStatus(
      String reportId, String studentId, AttendanceStatus status) async {
    if (state.pending > 0) await flushOutbox(); // keep changes in order
    final before = _report(reportId);
    if (before == null) return false;

    _replaceReport(
      reportId,
      (r) => r.copyWith(students: [
        for (final s in r.students)
          s.id == studentId ? s.copyWith(status: status) : s,
      ]),
    );

    try {
      await _sb
          .from('report_students')
          .update({'status': status.value}).eq('id', studentId);
    } catch (e) {
      if (_isOffline(e)) {
        await _queue({'op': 'status', 'student': studentId, 'status': status.value});
      } else {
        _replaceReport(reportId, (_) => before);
        rethrow;
      }
    }
    return _autoSubmit(reportId);
  }

  /// Give every student the same status (e.g. "Mark all present").
  Future<bool> setAllStatus(String reportId, AttendanceStatus status) async {
    if (state.pending > 0) await flushOutbox(); // keep changes in order
    final before = _report(reportId);
    if (before == null) return false;

    _replaceReport(
      reportId,
      (r) => r.copyWith(
        students: [for (final s in r.students) s.copyWith(status: status)],
      ),
    );

    try {
      await _sb
          .from('report_students')
          .update({'status': status.value}).eq('report_id', reportId);
    } catch (e) {
      if (_isOffline(e)) {
        await _queue({'op': 'all', 'report': reportId, 'status': status.value});
      } else {
        _replaceReport(reportId, (_) => before);
        rethrow;
      }
    }
    return _autoSubmit(reportId);
  }

  /// During a drill, the last unmarked student sends the report.
  Future<bool> _autoSubmit(String reportId) async {
    final r = _report(reportId);
    if (r == null) return false;
    if (state.drillActive &&
        !r.submitted &&
        r.students.isNotEmpty &&
        r.unmarked == 0) {
      await submitReport(reportId);
      return true;
    }
    return false;
  }

  /// Send this report to the timed console (can be re-sent after changes).
  Future<void> submitReport(String reportId) async {
    final dynamic res;
    try {
      // earlier offline changes must reach the server before the report is sent
      if (state.pending > 0) await flushOutbox();
      if (state.pending > 0) throw const SocketLikeOffline();
      res = await _sb
          .rpc('submit_attendance_report', params: {'p_report_id': reportId});
    } catch (e) {
      if (e is SocketLikeOffline || _isOffline(e)) {
        await _queue({'op': 'submit', 'report': reportId});
        _print('No connection: the report is saved on this phone and will be sent automatically.',
            ConsoleLevel.system);
        return;
      }
      rethrow;
    }
    final updated =
        AttendanceReport.fromRow(Map<String, dynamic>.from(res as Map));
    _replaceReport(reportId, (r) => updated.copyWith(students: r.students));
  }

  // ---------- drill control ----------

  Future<void> startDrill() async {
    if (state.drillActive) return;
    try {
      // every device (including this one) enters the drill via the stream
      await _sb.rpc('start_drill', params: {'p_school_year': schoolYear});
    } catch (e) {
      _print('Could not start drill: ${describe(e)}', ConsoleLevel.alert);
    }
  }

  Future<void> cancelDrill() async {
    final id = state.drillId;
    if (id == null || !state.drillActive) return;
    try {
      await _sb.rpc('cancel_drill', params: {'p_drill_id': id});
    } catch (e) {
      _print('Could not cancel drill: ${describe(e)}', ConsoleLevel.alert);
    }
  }

  /// Fires whenever the newest drill row changes (any device).
  void _onDrill(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return;
    final row = rows.first;
    final id = row['id'] as String;
    final status = row['status'] as String;
    final start = DateTime.parse(row['started_at'] as String).toLocal();

    if (id != state.drillId) {
      final stale = DateTime.now().difference(start) > _staleAfter;
      _ticker?.cancel();
      _completeRow = null;
      _completePrinted = false;
      if (status == 'active' && !stale) {
        _enterDrill(id, start);
      } else {
        emit(state.copyWith(
          clearDrill: true,
          drillActive: false,
          drillComplete: false,
        ));
      }
      return;
    }

    if (status == 'cancelled' && state.drillActive) {
      _ticker?.cancel();
      emit(state.copyWith(drillActive: false, drillComplete: false));
      _print('Evacuation drill cancelled.', ConsoleLevel.warning);
    } else if (status == 'complete' && state.drillActive) {
      _completeRow = row;
      _syncLog();
      _maybeFinish();
    }
  }

  void _enterDrill(String id, DateTime start) {
    emit(state.copyWith(
      drillId: id,
      drillActive: true,
      drillComplete: false,
      drillStart: start,
      elapsed: DateTime.now().difference(start),
      log: const [],
    ));

    // lines of this drill that were skipped as "history" get replayed
    final ids = state.feed.where((r) => r.drillId == id).map((r) => r.id);
    _printed.removeWhere((k) => ids.any((rid) => k.startsWith(rid)));

    final n = state.drillReports.length;
    _print(
      n > 0
          ? 'Evacuation drill started. Awaiting $n attendance report${n == 1 ? '' : 's'}.'
          : 'Evacuation drill started. Awaiting attendance reports.',
      ConsoleLevel.warning,
      start,
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state.drillStart;
      if (state.drillActive && s != null) {
        emit(state.copyWith(elapsed: DateTime.now().difference(s)));
      }
    });
    _syncLog();
  }

  // ---------- realtime reports ----------

  void _onFeed(List<Map<String, dynamic>> rows) {
    final feed = [
      for (final r in rows) AttendanceReport.fromRow(Map<String, dynamic>.from(r)),
    ];
    final initial = !_feedSeen;
    _feedSeen = true;
    emit(state.copyWith(feed: feed));
    _syncLog(initial: initial);
    _maybeFinish();
  }

  /// Writes a console line for every newly sent (or re-sent) report.
  void _syncLog({bool initial = false}) {
    final sent = state.feed
        .where((r) => r.submitted && r.submittedAt != null)
        .toList()
      ..sort((a, b) => a.submittedAt!.compareTo(b.submittedAt!));

    for (final r in sent) {
      final key = '${r.id}|${r.submittedAt!.toIso8601String()}';
      if (_printed.contains(key)) continue;
      _printed.add(key);

      // reports sent before this console opened are history, unless they
      // are part of the drill that is running now
      final inDrill = state.drillId != null && r.drillId == state.drillId;
      if (initial && !inDrill) continue;

      _printReport(r);
    }
  }

  /// "A", "A and B", "A, B and C"
  static String _joinNames(List<String> names) {
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} '
        'and ${names.last}';
  }

  void _printReport(AttendanceReport r) {
    // who is not present, by name (all present needs no names)
    final groups = <String>[
      for (final s in const [
        AttendanceStatus.missing,
        AttendanceStatus.injured,
        AttendanceStatus.absent,
      ])
        if (r.namesFor(s).isNotEmpty)
          '${s.label}: ${_joinNames(r.namesFor(s))}',
    ];

    final summary = groups.isEmpty
        ? 'All students are present.'
        : '${groups.join('. ')}. Present: ${r.present} of ${r.total}.';

    final level = r.missing > 0
        ? ConsoleLevel.alert
        : r.injured > 0
            ? ConsoleLevel.warning
            : ConsoleLevel.success;

    _print(
      '[${r.consoleLabel}] Attendance completed at ${r.site} '
      '(${r.emergencyType}). $summary',
      level,
      r.submittedAt,
    );
  }

  /// Prints "EVACUATION COMPLETE" once the database says the drill is done
  /// and every report line has been shown.
  void _maybeFinish() {
    final row = _completeRow;
    if (row == null || _completePrinted || !state.drillActive) return;

    final dr = state.drillReports;
    if (dr.isEmpty || dr.any((r) => !r.submitted)) return;

    final start = state.drillStart;
    if (start == null) return;
    _completePrinted = true;

    final end = row['ended_at'] != null
        ? DateTime.parse(row['ended_at'] as String).toLocal()
        : DateTime.now();
    final total = end.difference(start);

    final missing = dr.fold<int>(0, (s, r) => s + r.missing);
    final injured = dr.fold<int>(0, (s, r) => s + r.injured);

    _ticker?.cancel();
    emit(state.copyWith(
      drillActive: false,
      drillComplete: true,
      elapsed: total,
    ));

    final extras = <String>[
      if (missing > 0) 'Missing: $missing.',
      if (injured > 0) 'Injured: $injured.',
    ];
    _print(
      'EVACUATION COMPLETE. Total time: ${formatDurationWords(total)}. '
      '${extras.isEmpty ? 'All persons accounted for.' : extras.join(' ')}',
      missing > 0 ? ConsoleLevel.alert : ConsoleLevel.success,
      end,
    );
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _drillSub?.cancel();
    _feedSub?.cancel();
    _entries.close();
    return super.close();
  }
}
