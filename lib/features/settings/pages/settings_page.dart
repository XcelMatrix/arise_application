import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/utils/time_format.dart';
import 'package:arise_application/features/settings/cubit/settings_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';

/// Settings, in three groups: Appearance, Accessibility, Language and time.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
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
          final now = DateTime.now();
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // ------------------------------------------------ Appearance
              _Group(
                icon: Icons.palette_outlined,
                title: "Appearance",
                children: [
                  _Setting(children: [
                  _Label("Theme", "Choose how the app looks."),
                  _Dropdown<ThemeMode>(
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
                  ]),
                ],
              ),

              // ---------------------------------------------- Accessibility
              _Group(
                icon: Icons.accessibility_new,
                title: "Accessibility",
                children: [
                  _Setting(children: [
                  _Label("Text size",
                      "Make text larger or smaller, one pixel at a time."),
                  Row(
                    children: [
                      const Text.verbatim("A",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Expanded(
                        child: Slider(
                          value: settings.fontSize,
                          min: SettingsState.minFontSize,
                          max: SettingsState.maxFontSize,
                          divisions: (SettingsState.maxFontSize -
                                  SettingsState.minFontSize)
                              .round(),
                          label: '${settings.fontSize.round()} px',
                          activeColor: _blue,
                          onChanged: cubit.previewFontSize,
                          onChangeEnd: cubit.setFontSize,
                        ),
                      ),
                      const Text.verbatim("A",
                          style: TextStyle(fontSize: 24, color: Colors.grey)),
                      SizedBox(
                        width: 52,
                        child: Text.verbatim(
                          '${settings.fontSize.round()} px',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context)),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.field(context).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text("The quick brown fox jumps over the lazy dog.",
                        style: TextStyle(color: AppColors.body(context))),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          settings.fontSize == SettingsState.defaultFontSize
                              ? null
                              : () => cubit
                                  .setFontSize(SettingsState.defaultFontSize),
                      child: const Text("Reset"),
                    ),
                  ),
                  ]),
                  _Setting(children: [
                  _Label("Saturation",
                      "Lower it to make colors less intense, down to grey."),
                  Row(
                    children: [
                      const Icon(Icons.invert_colors_off,
                          size: 20, color: Colors.grey),
                      Expanded(
                        child: Slider(
                          value: settings.saturation,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          label: '${(settings.saturation * 100).round()}%',
                          activeColor: _blue,
                          onChanged: cubit.previewSaturation,
                          onChangeEnd: cubit.setSaturation,
                        ),
                      ),
                      const Icon(Icons.invert_colors,
                          size: 20, color: Colors.grey),
                      SizedBox(
                        width: 48,
                        child: Text.verbatim(
                          '${(settings.saturation * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context)),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: settings.saturation == 1.0
                          ? null
                          : () => cubit.setSaturation(1.0),
                      child: const Text("Reset"),
                    ),
                  ),
                  ]),
                ],
              ),

              // ------------------------------------------- Language and time
              _Group(
                icon: Icons.language,
                title: "Language and time",
                children: [
                  _Setting(children: [
                  _Label("Language", "Choose the language of the app."),
                  _Dropdown<String>(
                    value: Tr.byCode(settings.language).code,
                    items: [
                      for (final l in Tr.languages)
                        DropdownMenuItem(
                          value: l.code,
                          child: Row(children: [
                            Text.verbatim(l.flag,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text.verbatim(l.label,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        ),
                    ],
                    onChanged: cubit.setLanguage,
                  ),
                  ]),
                  _Setting(children: [
                  _Label("Time format",
                      "Show times with AM / PM or as a 24-hour clock."),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: _blue,
                        selectedForegroundColor: Colors.white,
                      ),
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.schedule),
                          label: Text.verbatim(
                              '12-hour  ·  ${_sample(now, false)}'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.schedule),
                          label: Text.verbatim(
                              '24-hour  ·  ${_sample(now, true)}'),
                        ),
                      ],
                      selected: {settings.use24h},
                      onSelectionChanged: (v) async {
                        await cubit.setUse24h(v.first);
                        if (context.mounted) rebuildAllScreens(context);
                      },
                    ),
                  ),
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _sample(DateTime t, bool use24) {
    final old = TimeFormat.use24h;
    TimeFormat.use24h = use24;
    final s = TimeFormat.short(t);
    TimeFormat.use24h = old;
    return s;
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
      initialValue: value,
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

/// Small title + explanation above a control.
class _Label extends StatelessWidget {
  const _Label(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                  fontFamily: 'Geist')),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey, fontFamily: 'Geist')),
        ],
      ),
    );
  }
}

/// A group: its name, then the settings that belong to it underneath.
class _Group extends StatelessWidget {
  const _Group({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Row(
              children: [
                Icon(icon, size: 22, color: const Color(0xFF3C6E87)),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C6E87),
                      fontFamily: 'Geist',
                    )),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// One setting (its name, explanation and control) under a group.
class _Setting extends StatelessWidget {
  const _Setting({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
