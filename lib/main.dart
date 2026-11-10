import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/auth_servers/auth_gate.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/cubits/calendar/calendar_cubit.dart';
import 'package:arise_application/cubits/drill/drill_cubit.dart';
import 'package:arise_application/cubits/inbox/inbox_cubit.dart';
import 'package:arise_application/cubits/settings/settings_cubit.dart';
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/theme/app_colors.dart';
import 'package:arise_application/cubits/profiles/profiles_cubit.dart';

const supabaseUrl = 'https://zpnykmhpzagnnmwhhjcp.supabase.co';
const supabasePublishableKey = 'sb_publishable_yRdFl4KBJXqTqmTzawMISQ_TaIS5Npl';

List<CameraDescription> allCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    allCameras = await availableCameras();
  } on CameraException catch (errorMessage) {
    // Provide more context in error handling
    debugPrint('Camera error: ${errorMessage.description}');
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfilesCubit>(create: (context) => ProfilesCubit()),
        // role, display name, avatar, feature access (reloads on login/logout)
        BlocProvider<AccountCubit>(create: (context) => AccountCubit()),
        // shared by Attendance pages + Timed Console
        BlocProvider<DrillCubit>(create: (context) => DrillCubit()..load()),
        // shared school calendar
        BlocProvider<CalendarCubit>(create: (context) => CalendarCubit()..load()),
        // theme + language
        BlocProvider<SettingsCubit>(create: (context) => SettingsCubit()..load()),
        // notifications: chat messages + Timed Console reports
        BlocProvider<InboxCubit>(
          create: (context) => InboxCubit(
            context.read<AccountCubit>(),
            context.read<DrillCubit>(),
          ),
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ARISE',
            // light mode = the original look (Flutter's default theme)
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            builder: (context, child) => LangScope(
              language: settings.language,
              child: child ?? const SizedBox.shrink(),
            ),
            home: AuthGate(),
          );
        },
      ),
    );
  }
}
