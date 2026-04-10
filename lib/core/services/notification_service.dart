library notification_service;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Singleton wrapper around `flutter_local_notifications` providing the
/// SpeedType-specific notification behaviours: daily streak reminders,
/// daily practice reminders and immediate level-up notifications.
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  static NotificationService get instance => _instance;

  // --- Notification IDs (stable across the app) ---
  static const int streakReminderId = 1;
  static const int dailyReminderId = 2;
  static const int levelUpId = 3;

  // --- Channel identifiers ---
  static const String _streakChannelId = 'streak_reminders';
  static const String _streakChannelName = 'Streak Reminders';
  static const String _streakChannelDesc =
      'Daily reminder to keep your typing streak alive.';

  static const String _dailyChannelId = 'daily_reminders';
  static const String _dailyChannelName = 'Daily Practice';
  static const String _dailyChannelDesc =
      'Daily reminder to practice typing on SpeedType.';

  static const String _levelUpChannelId = 'level_up';
  static const String _levelUpChannelName = 'Level Up';
  static const String _levelUpChannelDesc =
      'Celebratory notifications when you reach a new level.';

  // --- SharedPreferences flag keys ---
  static const String _kStreakEnabledKey = 'notification_streak';
  static const String _kDailyEnabledKey = 'notification_daily';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialise the plugin and timezone database. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;

    // Load the timezone DB and set local location.
    try {
      tzdata.initializeTimeZones();
      final String localName = tz.local.name;
      // If location wasn't set yet it may fall back to UTC; this keeps it
      // working across devices where the platform side hasn't pushed tz yet.
      if (localName.isEmpty || localName == 'UTC') {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: tz init warning: $e');
      }
    }

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTapped,
    );

    // Android 13+ requires runtime POST_NOTIFICATIONS permission; also
    // create the notification channels up front so the first schedule
    // succeeds without surprises.
    await _createAndroidChannels();

    _initialized = true;
  }

  /// Requests notification permission from the user. Platform-specific:
  /// - iOS/macOS: uses `requestPermissions` on the Darwin plugin.
  /// - Android 13+: uses `requestNotificationsPermission` on the Android
  ///   plugin. Earlier Android versions return `true` implicitly.
  Future<bool> requestPermission() async {
    await initialize();

    if (Platform.isIOS || Platform.isMacOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final bool? granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted =
          await androidPlugin?.requestNotificationsPermission();
      return granted ?? true;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Streak reminder (20:00 daily)
  // ---------------------------------------------------------------------------

  /// Schedules a daily reminder at 20:00 local time nudging the user to
  /// keep their streak alive. Pass the latest [currentStreak] so the
  /// message can be personalised.
  Future<void> scheduleStreakReminder(int currentStreak) async {
    await initialize();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool(_kStreakEnabledKey) ?? true;
    if (!enabled) {
      await cancelStreakReminder();
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _streakChannelId,
      _streakChannelName,
      channelDescription: _streakChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final String body = currentStreak > 0
        ? "Don't break your $currentStreak-day streak! Practice now to keep it alive."
        : 'Start a new streak today. 60 seconds is all it takes!';

    await _plugin.zonedSchedule(
      streakReminderId,
      'Your streak needs you!',
      body,
      _nextInstanceOf(20, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'streak_reminder',
    );
  }

  // ---------------------------------------------------------------------------
  // Daily practice reminder (09:00 daily)
  // ---------------------------------------------------------------------------

  /// Schedules a morning reminder at 09:00 local time.
  Future<void> scheduleDailyReminder() async {
    await initialize();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool enabled = prefs.getBool(_kDailyEnabledKey) ?? true;
    if (!enabled) {
      await _plugin.cancel(dailyReminderId);
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _dailyChannelId,
      _dailyChannelName,
      channelDescription: _dailyChannelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      dailyReminderId,
      'Good morning, typist!',
      'Warm up those fingers with a quick SpeedType session.',
      _nextInstanceOf(9, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );
  }

  // ---------------------------------------------------------------------------
  // Level-up celebration (immediate)
  // ---------------------------------------------------------------------------

  /// Shows an immediate notification celebrating a level-up.
  Future<void> showLevelUpNotification(String levelName, String level) async {
    await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _levelUpChannelId,
      _levelUpChannelName,
      channelDescription: _levelUpChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.show(
      levelUpId,
      '\u{1F389} Level Up!',
      'Congrats! You reached $levelName ($level). Keep climbing!',
      details,
      payload: 'level_up:$level',
    );
  }

  // ---------------------------------------------------------------------------
  // Cancellation helpers
  // ---------------------------------------------------------------------------

  /// Cancels only the streak reminder (ID 1).
  Future<void> cancelStreakReminder() async {
    await _plugin.cancel(streakReminderId);
  }

  /// Cancels every pending/active notification scheduled via this service.
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Computes the next [tz.TZDateTime] whose wall-clock time matches
  /// [hour]:[minute] in the local timezone. If that time has already
  /// passed today, it rolls forward by one day.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime.from(
      DateTime(now.year, now.month, now.day, hour, minute),
      tz.local,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    const AndroidNotificationChannel streakChannel = AndroidNotificationChannel(
      _streakChannelId,
      _streakChannelName,
      description: _streakChannelDesc,
      importance: Importance.high,
    );
    const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
      _dailyChannelId,
      _dailyChannelName,
      description: _dailyChannelDesc,
      importance: Importance.defaultImportance,
    );
    const AndroidNotificationChannel levelUpChannel =
        AndroidNotificationChannel(
      _levelUpChannelId,
      _levelUpChannelName,
      description: _levelUpChannelDesc,
      importance: Importance.max,
    );

    await androidPlugin.createNotificationChannel(streakChannel);
    await androidPlugin.createNotificationChannel(dailyChannel);
    await androidPlugin.createNotificationChannel(levelUpChannel);
  }

  /// Called when the user taps a notification while the app is alive.
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    if (kDebugMode) {
      debugPrint('NotificationService: tapped with payload=$payload');
    }
    // Navigation is handled by the app shell via a listener on a
    // navigation key — this hook is intentionally lightweight so that
    // deep-link logic lives in exactly one place.
  }
}

/// Top-level background handler required by the plugin when the app is
/// killed. Kept minimal — it logs and returns.
@pragma('vm:entry-point')
void _onBackgroundNotificationTapped(NotificationResponse response) {
  if (kDebugMode) {
    debugPrint(
      'NotificationService(bg): tapped with payload=${response.payload}',
    );
  }
}
