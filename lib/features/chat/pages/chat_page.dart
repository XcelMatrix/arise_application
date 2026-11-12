import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:arise_application/features/attendance/pages/attendance_page.dart';
import 'package:arise_application/features/console/pages/timed_console_page.dart';
import 'package:arise_application/features/resources/pages/disaster_resources_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/widgets/access_gate.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/account/widgets/user_avatar.dart';
import 'package:arise_application/features/chat/cubit/chat_cubit.dart';
import 'package:arise_application/features/chat/models/message.dart';
import 'package:arise_application/features/home/pages/home_page.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart';
import 'package:arise_application/features/chat/widgets/chat_image.dart';

/// Page to chat with someone: text, photos, edit / delete your own
/// messages, and search inside the conversation.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  static Route<void> route(String roomId) {
    return MaterialPageRoute(
      builder: (context) => BlocProvider<ChatCubit>(
        create: (context) => ChatCubit()..setMessagesListener(roomId),
        child: const ChatPage(),
      ),
    );
  }

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// the message being edited (shown in the message bar)
  Message? _editing;
  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccessGate(
        feature: Feature.chat,
        child: Builder(builder: _page),
      );

  static const int _currentIndex = 0;

  /// True if the signed-in account's role allows this feature.
  bool _allowed(BuildContext context, String feature) =>
      context.read<AccountCubit>().state.canAccess(feature);

  void _denied(BuildContext context) {
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

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1:
        if (!_allowed(context, Feature.attendance)) return _denied(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AttendancePage()),
        );
        break;
      case 2:
        if (!_allowed(context, Feature.timedConsole)) return _denied(context);
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
  }

  void _closeSearch() => setState(() {
        _searching = false;
        _query = '';
        _searchController.clear();
      });

  /// Long-press on your own message: edit / delete.
  Future<void> _messageActions(BuildContext context, Message m) async {
    final cubit = context.read<ChatCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Color(0xFF3C6E87)),
            title: const Text('Edit message'),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete message'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (action == 'edit') {
      setState(() => _editing = m);
    } else if (action == 'delete') {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This removes it for everyone in the chat.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (ok == true) {
        if (_editing?.id == m.id) setState(() => _editing = null);
        await cubit.deleteMessage(m.id);
      }
    }
  }

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _closeSearch,
              )
            : const BackOrLogo(),
        backgroundColor: const Color(0xFF3C6E87),
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontFamily: 'Geist'),
                decoration: InputDecoration(
                  hintText: tr(context, 'Search in this chat'),
                  hintStyle: const TextStyle(color: Color(0xB3FFFFFF)),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              )
            : const Text("Messages"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: <Widget>[
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            )
          else ...[
            IconButton(
              tooltip: 'Search in this chat',
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _searching = true),
            ),
            const ProfileMenuButton(),
          ],
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _visibleNav(context).indexOf(_currentIndex),
        onTap: (i) => _onItemTapped(context, _visibleNav(context, listen: false)[i]),
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
      body: BlocConsumer<ChatCubit, ChatState>(
        listener: (context, state) {
          if (state is ChatError) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        buildWhen: (_, s) => s is! ChatError,
        builder: (context, state) {
          final bar = MessageBar(
            editing: _editing,
            onCancelEdit: () => setState(() => _editing = null),
            onEditDone: () => setState(() => _editing = null),
          );
          if (state is ChatLoaded) {
            final all = state.messages;
            final messages = _query.isEmpty
                ? all
                : all.where((m) => m.content.toLowerCase().contains(_query)).toList();
            return Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Text("No results"))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return _ChatBubble(
                              message: message,
                              highlight: _query,
                              onLongPress: message.isMine
                                  ? () => _messageActions(context, message)
                                  : null,
                            );
                          },
                        ),
                ),
                bar,
              ],
            );
          } else if (state is ChatEmpty) {
            return Column(
              children: [
                const Expanded(
                  child: Center(
                    child: Text('Start your conversation now :',
                        style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF3C6E87),
                            fontFamily: 'Geist')),
                  ),
                ),
                bar,
              ],
            );
          } else if (state is ChatInitial) {
            return const FlashingLogo();
          }
          return const Center(child: Text("Something went wrong."));
        },
      ),
    );
  }
}

/// Text box, photo button and send button. Also used to edit a message.
class MessageBar extends StatefulWidget {
  const MessageBar({
    super.key,
    this.editing,
    this.onCancelEdit,
    this.onEditDone,
  });

  final Message? editing;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onEditDone;

  @override
  State<MessageBar> createState() => _MessageBarState();
}

class _MessageBarState extends State<MessageBar> {
  final _textController = TextEditingController();
  File? _image;
  bool _sending = false;

  @override
  void didUpdateWidget(MessageBar old) {
    super.didUpdateWidget(old);
    if (widget.editing != null && widget.editing?.id != old.editing?.id) {
      _textController.text = widget.editing!.content;
      _image = null;
    } else if (widget.editing == null && old.editing != null) {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFF3C6E87)),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: Color(0xFF3C6E87)),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final f = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (f != null && mounted) setState(() => _image = File(f.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't open the photo.")));
      }
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    final cubit = BlocProvider.of<ChatCubit>(context);
    final text = _textController.text;
    final editing = widget.editing;
    if (editing != null) {
      if (text.trim().isEmpty && !editing.hasImage) return;
      await cubit.editMessage(editing.id, text);
      _textController.clear();
      widget.onEditDone?.call();
      return;
    }
    if (text.trim().isEmpty && _image == null) return;
    setState(() => _sending = true);
    final img = _image;
    _textController.clear();
    setState(() => _image = null);
    await cubit.sendMessage(text, image: img);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return Material(
      color: AppColors.bg(context),
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          left: 8,
          right: 8,
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (editing)
              Container(
                width: double.infinity,
                color: AppColors.field(context),
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                child: Row(children: [
                  const Icon(Icons.edit, size: 16, color: Color(0xFF3C6E87)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Editing message')),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onCancelEdit,
                  ),
                ]),
              ),
            if (_image != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_image!, height: 90, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _image = null),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            Row(
              children: [
                if (!editing)
                  IconButton(
                    tooltip: 'Send a photo',
                    onPressed: _sending ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined,
                        color: Color(0xFF3C6E87), size: 26),
                  ),
                Expanded(
                  child: TextFormField(
                    keyboardType: TextInputType.multiline,
                    maxLines: 4,
                    minLines: 1,
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Type a message'),
                      hintStyle: const TextStyle(
                          fontSize: 16, color: Colors.grey, fontFamily: 'Geist'),
                      filled: true,
                      fillColor: AppColors.bg(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: AppColors.field(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: AppColors.field(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: AppColors.field(context)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _submit,
                  icon: Icon(
                    editing ? Icons.check_rounded : Icons.send_rounded,
                    color: const Color(0xFF3C6E87),
                    size: 26,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.highlight = '',
    this.onLongPress,
  });

  final Message message;
  final String highlight;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final textColor = mine ? Colors.white : AppColors.text(context);
    List<Widget> chatContents = [
      if (!mine) UserAvatar(userId: message.profileId),
      const SizedBox(width: 12),
      Flexible(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFF3C6E87) : AppColors.field(context),
              borderRadius: BorderRadius.circular(8),
              border: highlight.isNotEmpty
                  ? Border.all(color: Colors.amber, width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hasImage) ...[
                  ChatImage(path: message.imagePath!),
                  if (message.content.isNotEmpty) const SizedBox(height: 6),
                ],
                if (message.content.isNotEmpty)
                  Text.verbatim(
                    message.content,
                    style: TextStyle(color: textColor, fontFamily: 'Geist'),
                  ),
                if (message.edited)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'edited',
                      style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: textColor.withOpacity(0.7)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text.verbatim(format(message.createdAt, locale: 'en_short')),
      const SizedBox(width: 60),
    ];
    if (mine) chatContents = chatContents.reversed.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: chatContents,
      ),
    );
  }
}
