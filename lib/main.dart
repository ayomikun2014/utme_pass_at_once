import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:screen_protector/screen_protector.dart';

import 'features/user/providers/paystack_provider.dart';
import 'firebase_options.dart';
import 'core/services/network_service.dart';
import 'core/config/hive_setup.dart';

import 'core/constants/app_colors.dart';
import 'core/providers/app_theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/user/providers/store_provider.dart';
import 'features/user/providers/unlock_provider.dart';
import 'features/user/providers/ai_provider.dart';
import 'features/user/providers/news_provider.dart';
import 'features/user/providers/voucher_provider.dart';
import 'features/user/providers/syllabus_provider.dart';
import 'features/user/providers/simulator_provider.dart';
import 'core/providers/settings_provider.dart';
import 'features/user/providers/notification_provider.dart';
import 'features/user/providers/admission_provider.dart';
import 'features/user/providers/study_notes_provider.dart';
import 'features/user/providers/manual_payment_provider.dart';
import 'features/user/providers/video_provider.dart';
import 'features/user/providers/announcement_provider.dart';
import 'features/user/providers/admission_finder_provider.dart';

import 'routes.dart';
import 'core/screens/admin_gate_listener.dart';

// ================= GLOBAL KEYS =================
final GlobalKey<NavigatorState> rootNavigatorKey =
GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

// ================= BACKGROUND HANDLER =================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

// ================= MAIN =================
void main() {
  // A shipped phone's log is not the place for the app's running commentary:
  // uids, emails and internal errors all went to logcat in release builds.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FlutterAppBadgeControl.removeBadge();

    await _initApp();
  }, (error, stack) {
    debugPrint("ERROR: $error");
  });
}


// ================= INIT APP =================
Future<void> _initApp() async {
  try {
    // Enable Firestore offline caching for seamless offline eClassroom features
    FirebaseFirestore.instance.settings =
    const Settings(persistenceEnabled: true);

    await HiveSetup.init();
    await GoogleSignIn.instance.initialize();
    await NetworkService.instance.initialize();

    // Enable Screenshot & Screen Recording Prevention + Background blur
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithBlur();

    // Enable edge-to-edge UI drawing for modern system navigation padding
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    runApp(const UtmePassApp());
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("INIT ERROR: $e")),
      ),
    ));
  }
}

// ================= ROOT APP =================
class UtmePassApp extends StatelessWidget {
  const UtmePassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => UnlockProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()), // ✅ FIXED
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
        ChangeNotifierProvider(create: (_) => SyllabusProvider()),
        ChangeNotifierProvider(create: (_) => SimulatorProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AdmissionProvider()),
        ChangeNotifierProvider(create: (_) => StudyNotesProvider()),
        ChangeNotifierProvider(create: (_) => ManualPaymentProvider()),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider(create: (_) => AdmissionFinderProvider()),
      ],
      child: Consumer<AppThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode,
            theme: ThemeData.light().copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                primary: AppColors.primary,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryDark,
                brightness: Brightness.dark,
                primary: AppColors.primaryDark,
              ),
            ),
            routes: AppRoutes.staticRoutes,
            onUnknownRoute: AppRoutes.unknownRoute,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final overlayStyle = SystemUiOverlayStyle(
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
              );

              // AdminGateListener wraps the entire navigator tree so that
              // suspension / maintenance / force-update overlays appear
              // immediately on any screen the user happens to be on.
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: AdminGateListener(child: child ?? const SizedBox.shrink()),
              );
            },
          );
        },
      ),
    );
  }
}