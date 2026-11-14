import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/resources/data/offline_guides.dart';
import 'package:arise_application/translations/translated_text.dart';

const _blue = Color(0xFF3C6E87);

AppBar _bar(BuildContext context, String title, {Color color = _blue}) => AppBar(
      backgroundColor: color,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text.verbatim(title),
      titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist'),
      centerTitle: true,
    );

/// Evacuation steps, first aid and lockdown. Built into the app, so they
/// work with no signal at all.
class OfflineGuidesPage extends StatelessWidget {
  const OfflineGuidesPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const OfflineGuidesPage());

  @override
  Widget build(BuildContext context) {
    LangScope.of(context); // rebuild when the language changes
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _bar(context, tr(context, 'Emergency guides')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.offline_pin, color: Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('These guides are saved in the app and work without internet.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.text(context))),
                ),
              ],
            ),
          ),
          for (final g in offlineGuides)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 6,
                      offset: Offset(0, 3)),
                ],
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GuideDetailPage(guide: g))),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: g.color,
                  child: Icon(g.icon, color: Colors.white, size: 28),
                ),
                title: Text.verbatim(g.title.text,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                        fontFamily: 'Geist')),
                subtitle: Text.verbatim(g.summary.text),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
    );
  }
}

class GuideDetailPage extends StatelessWidget {
  const GuideDetailPage({super.key, required this.guide});
  final OfflineGuide guide;

  Future<void> _call(BuildContext context) async {
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: '911'))) return;
    } catch (_) {}
    await Clipboard.setData(const ClipboardData(text: '911'));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Number copied.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final note = guide.callNote;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: _bar(context, guide.title.text, color: guide.color),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (note != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFB3261E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFB3261E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.verbatim(note.text,
                      style: TextStyle(
                          color: AppColors.text(context), fontFamily: 'Geist')),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB3261E),
                        foregroundColor: Colors.white),
                    onPressed: () => _call(context),
                    icon: const Icon(Icons.phone),
                    label: Text('Call 911'),
                  ),
                ],
              ),
            ),
          for (final s in guide.sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text.verbatim(s.heading.text,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: guide.color,
                      fontFamily: 'Geist')),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final (i, step) in s.steps.steps.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: guide.color,
                            child: Text.verbatim('${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text.verbatim(step,
                                style: TextStyle(
                                    fontSize: 15,
                                    height: 1.35,
                                    color: AppColors.text(context),
                                    fontFamily: 'Geist')),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
