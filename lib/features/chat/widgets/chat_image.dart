import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/chat/cubit/chat_cubit.dart';

/// A photo from a chat message (private bucket, so it is loaded through a
/// short-lived signed link). Tap to view it full screen.
class ChatImage extends StatefulWidget {
  const ChatImage({super.key, required this.path});
  final String path;

  /// signed links, reused while they are still valid
  static final Map<String, (String, DateTime)> _links = {};

  static Future<String> link(String path) async {
    final hit = _links[path];
    if (hit != null && hit.$2.isAfter(DateTime.now())) return hit.$1;
    final url = await Supabase.instance.client.storage
        .from(ChatCubit.bucket)
        .createSignedUrl(path, 3600);
    _links[path] = (url, DateTime.now().add(const Duration(minutes: 50)));
    return url;
  }

  @override
  State<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<ChatImage> {
  late Future<String> _url = ChatImage.link(widget.path);

  @override
  void didUpdateWidget(ChatImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = ChatImage.link(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox(
              width: 200,
              height: 120,
              child: Center(child: Icon(Icons.broken_image, color: Colors.grey)));
        }
        if (!snap.hasData) {
          return const SizedBox(
              width: 200,
              height: 160,
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final url = snap.data!;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _FullImage(url: url)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                    width: 200,
                    height: 120,
                    child: Icon(Icons.broken_image, color: Colors.grey)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FullImage extends StatelessWidget {
  const _FullImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
