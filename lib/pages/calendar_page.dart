import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/cubits/calendar/calendar_cubit.dart';
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/l10n/translations.dart';
import 'package:arise_application/models/calendar_event.dart';
import 'package:arise_application/theme/app_colors.dart';

/// School calendar. Everyone can read it; teachers and admins can edit.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const CalendarPage());
  }

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _blue = Color(0xFF3C6E87);

  late DateTime _month; // first day of the month on show
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month, 1);
    context.read<CalendarCubit>().load();
  }

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _dateText(DateTime d) =>
      '${Tr.months[d.month - 1]} ${d.day}, ${d.year}';

  void _goMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  Future<void> _openForm({CalendarEvent? existing}) async {
    final cubit = context.read<CalendarCubit>();
    final result = await showDialog<_EventInput>(
      context: context,
      builder: (_) => _EventDialog(existing: existing, day: _selected),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await cubit.add(result.title, result.details, result.date, result.time);
      } else {
        await cubit.update(
            existing.id, result.title, result.details, result.date, result.time);
      }
      if (mounted) {
        setState(() {
          _selected = result.date;
          _month = DateTime(result.date.year, result.date.month, 1);
        });
      }
    } catch (e) {
      _toast('Could not save event: $e');
    }
  }

  Future<void> _delete(CalendarEvent e) async {
    final cubit = context.read<CalendarCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this event?'),
        content: Text.verbatim(e.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await cubit.delete(e.id);
    } catch (err) {
      _toast('Could not save event: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context); // rebuild when the language changes
    final canEdit = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.calendarEdit));

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _blue,
        title: const Text("Calendar"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: _blue,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add event',
                  style: TextStyle(color: Colors.white, fontFamily: 'Geist')),
            )
          : null,
      body: BlocBuilder<CalendarCubit, CalendarState>(
        builder: (context, state) {
          if (!state.loaded) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }
          final today = DateTime.now();
          final todayKey = DateTime(today.year, today.month, today.day);
          final monthEvents = state.events
              .where((e) =>
                  e.date.year == _month.year && e.date.month == _month.month)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.verbatim(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              _monthHeader(context),
              const SizedBox(height: 8),
              _weekdayRow(context),
              const SizedBox(height: 4),
              _grid(context, state, todayKey),
              const SizedBox(height: 16),

              // every event this month, visible without tapping anything
              Text(
                'Events in ${Tr.months[_month.month - 1]} ${_month.year}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                  fontFamily: 'Geist',
                ),
              ),
              const SizedBox(height: 8),
              if (monthEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No events this month.',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Geist')),
                )
              else
                for (final e in monthEvents)
                  _eventCard(context, e, canEdit, showDate: true),

              if (!canEdit)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    'Only teachers and admins can add or edit events.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey, fontFamily: 'Geist'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _monthHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: _blue,
          onPressed: () => _goMonth(-1),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              final now = DateTime.now();
              setState(() {
                _month = DateTime(now.year, now.month, 1);
                _selected = DateTime(now.year, now.month, now.day);
              });
            },
            child: Text.verbatim(
              '${Tr.months[_month.month - 1]} ${_month.year}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
                fontFamily: 'Geist',
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: _blue,
          onPressed: () => _goMonth(1),
        ),
      ],
    );
  }

  Widget _weekdayRow(BuildContext context) {
    return Row(
      children: [
        for (final d in Tr.weekdays)
          Expanded(
            child: Center(
              child: Text.verbatim(
                d,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontFamily: 'Geist',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(BuildContext context, CalendarState state, DateTime today) {
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday % 7; // Sunday = 0
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + days) / 7).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(context, state, today, r * 7 + c - leading + 1, days)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, CalendarState state, DateTime today,
      int dayNumber, int daysInMonth) {
    const cellHeight = 78.0;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: cellHeight);
    }
    final date = DateTime(_month.year, _month.month, dayNumber);
    final selected = _same(date, _selected);
    final isToday = _same(date, today);
    final events = state.on(date);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = date),
      child: Container(
        height: cellHeight,
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.fromLTRB(2, 3, 2, 2),
        decoration: BoxDecoration(
          color: events.isEmpty ? null : AppColors.card(context),
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: _blue, width: 1.5)
              : Border.all(color: AppColors.field(context).withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? _blue : null,
                shape: BoxShape.circle,
              ),
              child: Text.verbatim(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.white : AppColors.text(context),
                  fontFamily: 'Geist',
                ),
              ),
            ),
            const SizedBox(height: 2),
            for (final e in events.take(2))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFB3261E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text.verbatim(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontFamily: 'Geist',
                  ),
                ),
              ),
            if (events.length > 2)
              Text.verbatim(
                '+${events.length - 2}',
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Geist',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(BuildContext context, CalendarEvent e, bool canEdit,
      {bool showDate = false}) {
    final when = <String>[
      if (showDate) _dateText(e.date),
      if (e.time != null) e.time!.format(context),
    ].join('  •  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: Color(0xFFB3261E), width: 4)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.verbatim(
                  e.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                    fontFamily: 'Geist',
                  ),
                ),
                if (when.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.verbatim(
                      when,
                      style: const TextStyle(
                          fontSize: 12, color: _blue, fontFamily: 'Geist'),
                    ),
                  ),
                if (e.details != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text.verbatim(
                      e.details!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text(context),
                        fontFamily: 'Geist',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openForm(existing: e);
                if (v == 'delete') _delete(e);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit event')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}

class _EventInput {
  final String title;
  final String? details;
  final DateTime date;
  final TimeOfDay? time;
  const _EventInput(this.title, this.details, this.date, this.time);
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({this.existing, required this.day});

  final CalendarEvent? existing;
  final DateTime day;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final TextEditingController _title;
  late final TextEditingController _details;
  late DateTime _date;
  TimeOfDay? _time;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _details = TextEditingController(text: e?.details ?? '');
    _date = e?.date ?? widget.day;
    _time = e?.time;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  InputDecoration _dec(BuildContext context, String label) => InputDecoration(
        labelText: tr(context, label),
        labelStyle: const TextStyle(fontFamily: 'Geist'),
        filled: true,
        fillColor: AppColors.field(context),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(
      context,
      _EventInput(_title.text.trim(), _details.text, _date, _time),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add event' : 'Edit event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(context, 'Event title').copyWith(
                counterText: '',
                errorText: _showError ? tr(context, 'Enter a title') : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(context, 'Details (optional)'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event, color: Color(0xFF3C6E87)),
              title: Text.verbatim(
                  '${Tr.months[_date.month - 1]} ${_date.day}, ${_date.year}'),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: Color(0xFF3C6E87)),
              title: _time == null
                  ? const Text('Time (optional)')
                  : Text.verbatim(_time!.format(context)),
              trailing: _time == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: tr(context, 'Clear time'),
                      onPressed: () => setState(() => _time = null),
                    ),
              onTap: _pickTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
