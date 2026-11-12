import 'package:flutter/material.dart' hide Text;
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/auth/pages/auth_gate.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/announcements/cubit/announcements_cubit.dart';
import 'package:arise_application/features/calendar/cubit/calendar_cubit.dart';
import 'package:arise_application/features/inbox/cubit/teacher_requests_cubit.dart';
import 'package:arise_application/features/inbox/pages/inbox_page.dart';
import 'package:arise_application/features/alerts/widgets/alert_overlay.dart';
import 'package:arise_application/core/widgets/splash_gate.dart';
import 'package:arise_application/features/inbox/widgets/top_banner.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/features/console/cubit/audit_cubit.dart';
import 'package:arise_application/core/connectivity/connectivity_cubit.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/features/auth/pages/reset_password_page.dart';
import 'package:arise_application/features/console/cubit/drill_cubit.dart';
import 'package:arise_application/features/inbox/cubit/inbox_cubit.dart';
import 'package:arise_application/features/settings/cubit/settings_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/account/cubit/profiles_cubit.dart';

const supabaseUrl = 'https://zpnykmhpzagnnmwhhjcp.supabase.co';
const supabasePublishableKey = 'sb_publishable_yRdFl4KBJXqTqmTzawMISQ_TaIS5Npl';

List<CameraDescription> allCameras = [];

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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

  // the link in the "reset password" email opens the app and lands here
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(ResetPasswordPage.route());
    }
  });

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
        // shared by Attendance pages + Console
        BlocProvider<DrillCubit>(create: (context) => DrillCubit()..load()),
        // shared school calendar
        BlocProvider<CalendarCubit>(create: (context) => CalendarCubit()..load()),
        // announcements shown on Home
        BlocProvider<AnnouncementsCubit>(
            create: (context) => AnnouncementsCubit()..load()),
        // teacher approval (loads only for teachers/admins)
        BlocProvider<TeacherRequestsCubit>(
          create: (context) =>
              TeacherRequestsCubit(context.read<AccountCubit>()),
        ),
        BlocProvider<GuidelinesCubit>(
            create: (context) => GuidelinesCubit()..load()),
        BlocProvider<ContactsCubit>(create: (context) => ContactsCubit()..load()),
        BlocProvider<ClassListsCubit>(
            create: (context) => ClassListsCubit()..load()),
        BlocProvider<AlertLogCubit>(create: (context) => AlertLogCubit()..load()),
        BlocProvider<BuildingsCubit>(
            create: (context) => BuildingsCubit()..load()),
        BlocProvider<MapsCubit>(create: (context) => MapsCubit()..load()),
        BlocProvider<MarkersCubit>(
            create: (context) => MarkersCubit()..load()),
        BlocProvider<AuditCubit>(create: (context) => AuditCubit()),
        BlocProvider<AlertCubit>(create: (context) => AlertCubit(), lazy: false),
        BlocProvider<ConnectivityCubit>(
            create: (context) => ConnectivityCubit(), lazy: false),
        // theme + language
        BlocProvider<SettingsCubit>(create: (context) => SettingsCubit()..load()),
        // notifications: chat messages + Console reports
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
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            // light mode = the original look (Flutter's default theme)
            theme: null,
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            builder: (context, child) => _appShell(
              context,
              settings,
              // pop-up alert when something new arrives while the app is open
              child: BlocListener<InboxCubit, InboxState>(
                listenWhen: (a, b) =>
                    b.items.isNotEmpty &&
                    (a.items.isEmpty || a.items.first.id != b.items.first.id) &&
                    !b.items.first.read,
                listener: (context, inbox) {
                  final item = inbox.items.first;
                  final inboxCubit = context.read<InboxCubit>();
                  final requests = context.read<TeacherRequestsCubit>();
                  final isRequest =
                      item.kind == InboxKind.request && item.refId != null;

                  Future<void> decide(bool approve) async {
                    try {
                      approve
                          ? await requests.approve(item.refId!)
                          : await requests.reject(item.refId!);
                      inboxCubit.markRead(item.id);
                      scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
                        content: Text(approve ? 'Teacher approved.' : 'Request declined.'),
                        duration: const Duration(seconds: 2),
                      ));
                    } catch (e) {
                      scaffoldMessengerKey.currentState?.showSnackBar(
                          SnackBar(content: Text.verbatim('$e')));
                    }
                  }

                  // quick pop-up at the top; it also stays in the Inbox
                  TopBanner.show(
                    navigatorKey,
                    item,
                    onOpen: () =>
                        navigatorKey.currentState?.push(InboxPage.route()),
                    onAccept: isRequest ? () => decide(true) : null,
                    onDecline: isRequest ? () => decide(false) : null,
                  );
                },
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: SplashGate(child: AuthGate()),
          );
        },
      ),
    );
  }
}

/// Text size, bold text for high contrast, translations, the offline
/// banner and the full-screen emergency alert, around the whole app.
Widget _appShell(BuildContext context, SettingsState settings,
    {required Widget child}) {
  final mq = MediaQuery.of(context);
  final system = mq.textScaler.scale(14) / 14;
  return MediaQuery(
    data: mq.copyWith(
      textScaler: TextScaler.linear(system * settings.textScale),
      alwaysUse24HourFormat: settings.use24h,
    ),
    child: _Saturation(
      value: settings.saturation,
      child: LangScope(
      language: settings.language,
      child: BlocListener<ConnectivityCubit, bool>(
        listener: (context, online) {
          final m = scaffoldMessengerKey.currentState;
          if (online) {
            m?.hideCurrentMaterialBanner();
            // back online: refresh everything that was showing a saved copy
            context.read<DrillCubit>().flushOutbox();
            context.read<GuidelinesCubit>().load();
            context.read<ContactsCubit>().load();
            context.read<ClassListsCubit>().load();
            context.read<AnnouncementsCubit>().load();
            context.read<AlertCubit>().load();
          } else {
            m
              ?..hideCurrentMaterialBanner()
              ..showMaterialBanner(MaterialBanner(
                leading: const Icon(Icons.cloud_off),
                content: const Text('You are offline. Showing saved information.'),
                actions: [
                  TextButton(
                    onPressed: () => m.hideCurrentMaterialBanner(),
                    child: const Text('Dismiss'),
                  ),
                ],
              ));
          }
        },
        child: AlertOverlay(child: child),
      ),
    ),
    ),
  );
}

/// Colour saturation for the whole app (Settings > Accessibility).
/// 1.0 leaves the app untouched (no extra drawing cost).
class _Saturation extends StatelessWidget {
  const _Saturation({required this.value, required this.child});
  final double value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (value >= 0.999) return child;
    const r = 0.2126, g = 0.7152, b = 0.0722; // how bright each colour looks
    final s = value;
    final sr = (1 - s) * r, sg = (1 - s) * g, sb = (1 - s) * b;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        sr + s, sg, sb, 0, 0, //
        sr, sg + s, sb, 0, 0, //
        sr, sg, sb + s, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
      child: child,
    );
  }
}
