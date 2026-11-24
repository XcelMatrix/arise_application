import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';

/// Short introduction shown once, the first time the app is opened, before
/// the login / register page. [onDone] is called by Skip and Get started.
class TourPage extends StatefulWidget {
  const TourPage({super.key, required this.onDone});

  final VoidCallback onDone;

  static const _prefKey = 'arise_intro_seen';

  static Future<bool> alreadySeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (_) {}
  }

  @override
  State<TourPage> createState() => _TourPageState();
}

class _Slide {
  final String title;
  final String text;
  final String? image;
  final IconData icon;
  const _Slide(this.title, this.text, this.image, this.icon);
}

class _TourPageState extends State<TourPage> {
  static const _blue = Color(0xFF3C6E87);

  // a short introduction, not a how-to: the full details are in Help
  static const _allSlides = [
    _Slide(
      'Welcome to ARISE',
      'Your school\'s drill and evacuation companion. Here is a quick look around.',
      'assets/icons/icon.png',
      Icons.shield_outlined,
    ),
    _Slide(
      'Disaster Resources',
      'Everything you need to prepare for and respond to an emergency, in one place.',
      null,
      Icons.health_and_safety,
    ),
    _Slide(
      'Guidelines',
      'Clear steps for what to do before, during and after a disaster.',
      null,
      Icons.menu_book,
    ),
    _Slide(
      'Contacts',
      'Important emergency numbers, one tap away.',
      null,
      Icons.contact_phone,
    ),
    _Slide(
      'Maps',
      'See the evacuation plan of each building, in AR or as an image.',
      'assets/images/evacuation_banner.png',
      Icons.view_in_ar,
    ),
    _Slide(
      'Attendance',
      'For teachers and admins: take attendance during a drill and send your report.',
      'assets/images/attendance_banner.png',
      Icons.assignment_turned_in,
    ),
    _Slide(
      'Console',
      'For teachers and admins: follow drills live and see who has reported.',
      'assets/images/console_banner.png',
      Icons.terminal,
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await TourPage.markSeen();
    if (!mounted) return;
    widget.onDone();
  }

  Widget _picture(_Slide s) {
    final fallback = Container(
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: Icon(s.icon, size: 96, color: Colors.white)),
    );
    if (s.image == null) return fallback;
    if (s.image == 'assets/icons/icon.png') {
      // first slide: the ARISE icon with the ARISE wordmark under it, as on
      // the login page but bigger, centred and always inside the screen
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 5,
              child: Image.asset('assets/icons/icon.png',
                  fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback),
            ),
            const SizedBox(height: 12),
            Flexible(
              flex: 2,
              child: Image.asset('assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        s.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = _allSlides;
    final last = _page >= slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip',
                    style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Geist')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Expanded(child: _picture(s)),
                        const SizedBox(height: 24),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _blue,
                                fontFamily: 'Geist')),
                        const SizedBox(height: 10),
                        Text(s.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                color: AppColors.body(context),
                                fontFamily: 'Geist')),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? _blue : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: last
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                  child: Text(last ? 'Get started' : 'Next',
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontFamily: 'Geist')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
