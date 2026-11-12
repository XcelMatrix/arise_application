import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/features/inbox/widgets/inbox_style.dart';
import 'package:arise_application/features/inbox/cubit/inbox_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';

/// Quick pop-up at the top of the screen for a new notification.
/// It slides in, stays a few seconds, then slides away (the notification
/// stays in the Inbox). Teacher requests also get Decline / Accept buttons.
class TopBanner {
  static OverlayEntry? _current;
  static void Function()? _closeCurrent;

  static void show(
    GlobalKey<NavigatorState> navigatorKey,
    InboxItem item, {
    VoidCallback? onOpen,
    Future<void> Function()? onAccept,
    Future<void> Function()? onDecline,
  }) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _closeCurrent?.call();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerCard(
        item: item,
        onOpen: onOpen,
        onAccept: onAccept,
        onDecline: onDecline,
        onClosed: () {
          if (entry.mounted) entry.remove();
          if (_current == entry) {
            _current = null;
            _closeCurrent = null;
          }
        },
        registerClose: (close) => _closeCurrent = close,
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _BannerCard extends StatefulWidget {
  const _BannerCard({
    required this.item,
    required this.onClosed,
    required this.registerClose,
    this.onOpen,
    this.onAccept,
    this.onDecline,
  });

  final InboxItem item;
  final VoidCallback onClosed;
  final void Function(void Function()) registerClose;
  final VoidCallback? onOpen;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Timer? _timer;
  bool _busy = false;
  bool _closing = false;

  bool get _hasActions => widget.onAccept != null;

  @override
  void initState() {
    super.initState();
    widget.registerClose(_close);
    _c.forward();
    _startTimer(_hasActions ? 8 : 4);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: seconds), _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) {
      try {
        await _c.reverse();
      } catch (_) {}
    }
    widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _decide(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      await action();
    } finally {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final verbatim = inboxIsVerbatim(item);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
          child: Dismissible(
            key: const ValueKey('top_banner'),
            direction: DismissDirection.up,
            onDismissed: (_) {
              _timer?.cancel();
              widget.onClosed();
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: dark ? const Color(0xFF1E2A31) : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _hasActions
                      ? null
                      : () {
                          widget.onOpen?.call();
                          _close();
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: inboxColor(item),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(inboxIcon(item),
                                  color: Colors.white, size: 21),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  verbatim
                                      ? Text.verbatim(item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Geist'))
                                      : Text(item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Geist')),
                                  verbatim
                                      ? Text.verbatim(item.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Geist'))
                                      : Text(item.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Geist')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_hasActions) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy || widget.onDecline == null
                                      ? null
                                      : () => _decide(widget.onDecline!),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3C6E87),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(widget.onAccept!),
                                  child: const Text('Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
