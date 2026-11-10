import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/theme/app_colors.dart';
import 'package:arise_application/pages/register_page.dart';

/// Shown before registration: teacher (needs approval) or student.
class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.bg(context),
        elevation: 0,
        iconTheme: const IconThemeData(color: _blue),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          children: [
            Center(
              child: Image.asset("assets/icons/icon.png", width: 80, height: 80),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you registering as a teacher or a student?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _blue,
                fontFamily: 'Geist',
              ),
            ),
            const SizedBox(height: 28),
            _RoleCard(
              title: 'Teacher',
              icon: Icons.edit,
              description:
                  'A teacher account can take attendance, run drills and use '
                  'the chat. It has to be approved first.',
              onTap: () => Navigator.push(
                context,
                RegisterPage.route(isTeacher: true),
              ),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'Student',
              icon: Icons.school,
              description:
                  'A student account can view the evacuation map and manage '
                  'its own profile.',
              onTap: () => Navigator.push(
                context,
                RegisterPage.route(),
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Center(
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(
                    fontSize: 16,
                    color: _blue,
                    fontFamily: 'Geist',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.soft(context),
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.body(context),
                        fontFamily: 'Geist',
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.body(context)),
                ],
              ),
              const SizedBox(height: 16),
              Icon(icon, size: 64, color: _blue),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: _blue,
                  fontFamily: 'Geist',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
