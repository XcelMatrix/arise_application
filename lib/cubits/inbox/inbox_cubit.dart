import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/cubits/drill/drill_cubit.dart';
import 'package:arise_application/models/attendance_models.dart';

enum InboxKind { chat, console }

class InboxItem {
  final int id;
  final InboxKind kind;
  final String title;
  final String body;
  final DateTime time;
  final ConsoleLevel level;
  final bool read;

  const InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.level = ConsoleLevel.info,
    this.read = false,
  });

  InboxItem asRead() => InboxItem(
        id: id,
        kind: kind,
        title: title,
        body: body,
        time: time,
        level: level,
        read: true,
      );
}

class InboxState {
  final List<InboxItem> items;
  const InboxState({this.items = const []});

  int get unread => items.where((i) => !i.read).length;
}

/// Collects notifications while the app is open: new chat messages from
/// other people, and lines the Timed Console prints (attendance reports,
/// drill started / cancelled / complete).
class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._account, this._drill) : super(const InboxState()) {
    _accountSub = _account.stream.listen(_onAccount);
    _consoleSub = _drill.entries.listen(_onConsole);
    _onAccount(_account.state);
  }

  final AccountCubit _account;
  final DrillCubit _drill;
  final _supabase = Supabase.instance.client;

  StreamSubscription<AccountState>? _accountSub;
  StreamSubscription<ConsoleEntry>? _consoleSub;
  RealtimeChannel? _channel;

  String? _uid;
  int _nextId = 0;
  final Map<String, String> _names = {};

  static const _maxItems = 100;

  // ---------- account / login changes ----------

  void _onAccount(AccountState account) {
    final uid = _supabase.auth.currentUser?.id;

    // a different person signed in (or out): start fresh
    if (uid != _uid) {
      _stopChat();
      _names.clear();
      if (!isClosed) emit(const InboxState());
      _uid = uid;
    }

    final canChat =
        uid != null && account.loaded && account.canAccess(Feature.chat);
    if (canChat) {
      _startChat();
    } else {
      _stopChat();
    }
  }

  // ---------- chat messages ----------

  void _startChat() {
    if (_channel != null) return;
    _channel = _supabase
        .channel('inbox-messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: _onMessage,
        )
        .subscribe();
  }

  void _stopChat() {
    final c = _channel;
    _channel = null;
    if (c != null) _supabase.removeChannel(c);
  }

  Future<void> _onMessage(PostgresChangePayload payload) async {
    final row = payload.newRecord;
    final senderId = row['profile_id'] as String?;
    if (senderId == null || senderId == _uid) return;

    final text = (row['content'] as String?) ?? '';
    final name = await _nameFor(senderId);
    _add(InboxItem(
      id: _nextId++,
      kind: InboxKind.chat,
      title: name,
      body: text,
      time: DateTime.now(),
    ));
  }

  Future<String> _nameFor(String id) async {
    final cached = _names[id];
    if (cached != null) return cached;
    var name = 'Someone';
    try {
      final row = await _supabase
          .from('profiles')
          .select('username, profile_details(display_name)')
          .eq('id', id)
          .maybeSingle();
      if (row != null) {
        final d = row['profile_details'];
        final details = d is List ? (d.isEmpty ? null : d.first) : d;
        final display = details is Map ? details['display_name'] as String? : null;
        final username = row['username'] as String?;
        name = (display != null && display.trim().isNotEmpty)
            ? display.trim()
            : (username ?? name);
      }
    } catch (_) {}
    _names[id] = name;
    return name;
  }

  // ---------- timed console ----------

  void _onConsole(ConsoleEntry e) {
    // our own failed actions are not news
    if (e.message.startsWith('Could not') ||
        e.message.startsWith('Lost connection')) {
      return;
    }
    final upper = e.message.toUpperCase();
    final title = e.message.startsWith('[')
        ? 'Attendance report'
        : upper.contains('EVACUATION COMPLETE')
            ? 'Evacuation complete'
            : 'Evacuation drill';
    _add(InboxItem(
      id: _nextId++,
      kind: InboxKind.console,
      title: title,
      body: e.message,
      time: e.time,
      level: e.level,
    ));
  }

  // ---------- list ----------

  void _add(InboxItem item) {
    if (isClosed) return;
    emit(InboxState(items: [item, ...state.items].take(_maxItems).toList()));
  }

  void markRead(int id) {
    emit(InboxState(items: [
      for (final i in state.items) i.id == id ? i.asRead() : i,
    ]));
  }

  void markAllRead() {
    emit(InboxState(items: [for (final i in state.items) i.asRead()]));
  }

  void clear() => emit(const InboxState());

  @override
  Future<void> close() {
    _accountSub?.cancel();
    _consoleSub?.cancel();
    _stopChat();
    return super.close();
  }
}
