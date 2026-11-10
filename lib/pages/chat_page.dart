import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/theme/app_colors.dart';
import 'package:arise_application/components/app_drawer.dart';
import 'package:arise_application/components/profile_menu_button.dart';
import 'package:arise_application/pages/attendance_page.dart';
import 'package:arise_application/pages/timed_console_page.dart';
import 'package:arise_application/pages/disaster_resources_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/components/access_gate.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/components/user_avatar.dart';
import 'package:arise_application/cubits/chat/chat_cubit.dart';
import 'package:arise_application/models/message.dart';
import 'package:arise_application/pages/home_page.dart';
import 'package:timeago/timeago.dart';

/// Page to chat with someone.
/// Displays chat bubbles as a ListView and TextField to enter new chat.
class ChatPage extends StatelessWidget {
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

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      endDrawer: const AppDrawer(),
      appBar: AppBar(

        // ARISE white logo
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/icons/icon_white.png", width: 48, height: 48),
        ),
        backgroundColor: Color(0xFF3C6E87),

        // Page title
        title: const Text("Messages"),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist'
        ),
        centerTitle: true,

        // Profile button
        actions: <Widget>[
const ProfileMenuButton()
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => _onItemTapped(context, i),
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
        ],
      ),
      body: BlocConsumer<ChatCubit, ChatState>(
        listener: (context, state) {
          if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: ${state.message} ")));
          }
        },
        builder: (context, state) {
          if (state is ChatInitial) {
            return Center(child: CircularProgressIndicator(color: Color(0xFF3C6E87)));
          } else if (state is ChatLoaded) {
            final messages = state.messages;
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _ChatBubble(message: message);
                    },
                  ),
                ),
                const MessageBar(),
              ],
            );
          } else if (state is ChatEmpty) {
            return Column(
              children: const [
                Expanded(
                  child: Center(
                    child: Text(
                      'Start your conversation now :',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF3C6E87),
                        fontFamily: 'Geist'
                      )
                      ),
                  ),
                ),
                MessageBar(),
              ],
            );
          } else if (state is ChatError) {
            return Center(child: Text(state.message));
          }
          throw UnimplementedError();
        },
      ),
    );
  }
}

/// Set of widget that contains TextField and Button to submit message
class MessageBar extends StatefulWidget {
  const MessageBar({super.key});

  @override
  State<MessageBar> createState() => _MessageBarState();
}

class _MessageBarState extends State<MessageBar> {
  late final TextEditingController _textController;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg(context),
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          left: 8,
          right: 8,
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                keyboardType: TextInputType.text,
                maxLines: null,
                autofocus: true,
                controller: _textController,
                decoration: InputDecoration(
                  hintText: tr(context, 'Type a message'),
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontFamily: 'Geist'
                  ),
                  filled: true,
                  fillColor: AppColors.bg(context),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),

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
              onPressed: _submitMessage,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    _textController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitMessage() async {
    final text = _textController.text;
    if (text.isEmpty) {
      return;
    }
    BlocProvider.of<ChatCubit>(context).sendMessage(text);
    _textController.clear();
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
  });

  final Message message;

  @override
  Widget build(BuildContext context) {
    List<Widget> chatContents = [
      if (!message.isMine) UserAvatar(userId: message.profileId),
      const SizedBox(width: 12),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: message.isMine
                ? Color(0xFF3C6E87)
                : AppColors.field(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text.verbatim(
            message.content,
            style: TextStyle(
              color: message.isMine ? Colors.white : Colors.grey,
              fontFamily: 'Geist'
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(format(message.createdAt, locale: 'en_short')),
      const SizedBox(width: 60),
    ];
    if (message.isMine) {
      chatContents = chatContents.reversed.toList();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      child: Row(
        mainAxisAlignment:
            message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: chatContents,
      ),
    );
  }
}