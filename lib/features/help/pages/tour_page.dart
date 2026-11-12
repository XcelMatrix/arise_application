import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/home/pages/home_page.dart';

/// Short first-run tour shown after pressing Log in.
/// Skip goes straight to Home. "Don't show this again" turns it off.
class TourPage extends StatefulWidget {
  const TourPage({super.key});

  static const _prefKey = 'arise_tour_hidden';

  static Route<void> route() =>
      MaterialPageRoute(builder: (context) => const TourPage());

  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_prefKey) ?? false);
    } catch (_) {
      return true;
    }
  }

  /// Called after a successful login: tour first, otherwise Home.
  static Future<void> openAfterLogin(BuildContext context) async {
    final show = await shouldShow();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      show
          ? route()
          : MaterialPageRoute(builder: (context) => const HomePage()),
    );
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

  static const _slides = [
    _Slide(
      'Welcome to ARISE',
      'Your school\'s drill and evacuation companion. Here is a quick look around.',
      'assets/icons/icon.png',
      Icons.shield_outlined,
    ),
    _Slide(
      'Evacuation Map',
      'View the evacuation map in AR. Drag to move, pinch to zoom, twist to rotate. If AR is not available, a map image is shown instead.',
      'assets/images/evacuation_banner.png',
      Icons.view_in_ar,
    ),
    _Slide(
      'Attendance',
      'Teachers take attendance during a drill and mark each student Present, Absent, Missing or Injured, then send the report.',
      'assets/images/attendance_banner.png',
      Icons.assignment_turned_in,
    ),
    _Slide(
      'Console',
      'Reports appear live. Start a drill and watch the clock until every section has reported.',
      'assets/images/console_banner.png',
      Icons.terminal,
    ),
    _Slide(
      'Stay informed',
      'The bell shows your latest notifications. Announcements from teachers and admins appear at the top of Home.',
      null,
      Icons.notifications_active,
    ),
    _Slide(
      'Your menu',
      'Tap your picture for Inbox, Calendar, Settings, About and Help. You can open this guide again anytime from Help.',
      null,
      Icons.account_circle,
    ),
  ];

  final _controller = PageController();
  int _page = 0;
  bool _dontShow = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_dontShow) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(TourPage._prefKey, true);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        s.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
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
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
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
                for (var i = 0; i < _slides.length; i++)
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
            if (last)
              CheckboxListTile(
                value: _dontShow,
                onChanged: (v) => setState(() => _dontShow = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _blue,
                title: const Text("Don't show this again",
                    style: TextStyle(fontSize: 14, fontFamily: 'Geist')),
              )
            else
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
