import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/constants.dart';
import 'features/home/home_screen.dart';
import 'features/typing_test/typing_test_screen.dart';
import 'features/daily_challenge/daily_challenge_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(Constants.keyOnboardingDone) ?? false;

  runApp(
    ProviderScope(
      child: SpeedTypeApp(onboardingDone: onboardingDone),
    ),
  );
}

class SpeedTypeApp extends StatelessWidget {
  final bool onboardingDone;

  const SpeedTypeApp({super.key, required this.onboardingDone});

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
      title: Constants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
