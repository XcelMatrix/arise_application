import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/cubits/settings/settings_cubit.dart';
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/l10n/translations.dart';
import 'package:arise_application/theme/app_colors.dart';

/// Theme (light / dark) and language (English / Filipino).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    final segmentStyle = SegmentedButton.styleFrom(
      selectedBackgroundColor: _blue,
      selectedForegroundColor: Colors.white,
    );

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _blue,
        title: const Text("Settings"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          final cubit = context.read<SettingsCubit>();
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              _Section(
                icon: Icons.brightness_6,
                title: "Theme",
                subtitle: "Choose how the app looks.",
                child: SegmentedButton<ThemeMode>(
                  style: segmentStyle,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text("Light"),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text("Dark"),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (v) => cubit.setTheme(v.first),
                ),
              ),
              _Section(
                icon: Icons.language,
                title: "Language",
                subtitle: "Choose the language of the app.",
                child: SegmentedButton<AppLanguage>(
                  style: segmentStyle,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AppLanguage.english,
                      label: Text.verbatim("English"),
                    ),
                    ButtonSegment(
                      value: AppLanguage.filipino,
                      label: Text.verbatim("Filipino"),
                    ),
                  ],
                  selected: {settings.language},
                  onSelectionChanged: (v) => cubit.setLanguage(v.first),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3C6E87),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                        fontFamily: 'Geist',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Geist',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}
