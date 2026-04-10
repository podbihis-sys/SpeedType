// DEMO MODE entry point for SpeedType
//
// This bypasses Firebase/Crashlytics/AdMob initialization so you can preview
// the UI locally in seconds:
//
//   flutter pub get
//   flutter run -t lib/main_demo.dart -d chrome
//
// Or for desktop (if enabled):
//   flutter run -t lib/main_demo.dart -d macos      # or linux/windows
//
// Firebase-dependent features (Auth, Firestore, Cloud Functions, AdMob,
// Push Notifications, RevenueCat) will NOT work in demo mode - they use
// mock data or are stubbed out. Once you've done the Firebase setup
// (steps 1-4 in the plan), switch back to `lib/main.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';
import 'features/auth/login_screen.dart';
import 'features/daily_challenge/daily_challenge_screen.dart';
import 'features/home/home_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/typing_test/typing_test_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait on mobile (ignored on desktop/web).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Read onboarding flag from SharedPreferences so the first run lands on
  // /onboarding and subsequent runs go straight to /home.
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(Constants.keyOnboardingDone) ?? false;

  runApp(
    ProviderScope(
      child: SpeedTypeDemoApp(onboardingDone: onboardingDone),
    ),
  );
}

class SpeedTypeDemoApp extends StatelessWidget {
  final bool onboardingDone;

  const SpeedTypeDemoApp({super.key, required this.onboardingDone});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: onboardingDone ? '/home' : '/onboarding',
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) =>
              onboardingDone ? '/home' : '/onboarding',
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/test',
          builder: (context, state) => const TypingTestScreen(),
        ),
        GoRoute(
          path: '/daily',
          builder: (context, state) => const DailyChallengeScreen(),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (context, state) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: '${Constants.appName} (Demo)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
