import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/settings/cubit/settings_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';
import 'package:arise_application/core/theme/app_colors.dart';

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
                child: _Dropdown<ThemeMode>(
                  value: settings.themeMode == ThemeMode.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: _Option(Icons.light_mode, "Light"),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: _Option(Icons.dark_mode, "Dark"),
                    ),
                  ],
                  onChanged: cubit.setTheme,
                ),
              ),
              _Section(
                icon: Icons.text_fields,
                title: "Text size",
                subtitle: "Make text larger and easier to read.",
                child: SegmentedButton<double>(
                  style: segmentStyle,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1.0, label: Text("Normal")),
                    ButtonSegment(value: 1.25, label: Text("Large")),
                    ButtonSegment(value: 1.5, label: Text("Extra large")),
                  ],
                  selected: {settings.textScale},
                  onSelectionChanged: (v) => cubit.setTextScale(v.first),
                ),
              ),
              _Section(
                icon: Icons.contrast,
                title: "High contrast",
                subtitle: "Stronger colors, bold text and clear borders.",
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: _blue,
                  title: const Text("High contrast"),
                  value: settings.highContrast,
                  onChanged: cubit.setHighContrast,
                ),
              ),
              _Section(
                icon: Icons.language,
                title: "Language",
                subtitle: "Choose the language of the app.",
                child: _Dropdown<String>(
                  value: Tr.byCode(settings.language).code,
                  items: [
                    for (final l in Tr.languages)
                      DropdownMenuItem(
                        value: l.code,
                        child: Text.verbatim(l.label),
                      ),
                  ],
                  onChanged: cubit.setLanguage,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF3C6E87)),
        const SizedBox(width: 10),
        Text(label),
      ]);
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      dropdownColor: AppColors.card(context),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.field(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
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
