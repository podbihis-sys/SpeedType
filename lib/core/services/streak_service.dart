import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result returned after recording a test completion.
class StreakResult {
  final int newStreak;
  final bool isNewRecord;
  final bool streakFreezeUsed;
  final bool streakLost;

  const StreakResult({
    required this.newStreak,
    required this.isNewRecord,
    required this.streakFreezeUsed,
    required this.streakLost,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'newStreak': newStreak,
        'isNewRecord': isNewRecord,
        'streakFreezeUsed': streakFreezeUsed,
        'streakLost': streakLost,
      };

  @override
  String toString() =>
      'StreakResult(newStreak: $newStreak, isNewRecord: $isNewRecord, streakFreezeUsed: $streakFreezeUsed, streakLost: $streakLost)';
}

/// Singleton service for tracking daily typing streaks.
///
/// A streak increments when the user completes at least one test in a
/// UTC calendar day. Missing a day resets the streak, unless a streak freeze
/// has been activated, which covers a single day of inactivity.
class StreakService {
  StreakService._internal();

  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  static StreakService get instance => _instance;

  // --- Hive box ---
  static const String _boxName = 'streak_data';

  // --- Keys ---
  static const String _kCurrentStreak = 'currentStreak';
  static const String _kLongestStreak = 'longestStreak';
  static const String _kLastTestDate = 'lastTestDate'; // ISO-8601 UTC date
  static const String _kHasStreakFreeze = 'hasStreakFreeze';
  static const String _kFreezeActivatedAt = 'freezeActivatedAt';
  static const String _kLostStreakValue = 'lostStreakValue';
  static const String _kLostStreakAt = 'lostStreakAt';

  /// How long after losing a streak the user can still restore it.
  static const Duration _restoreWindow = Duration(hours: 48);

  /// Number of rewarded ads required to restore a lost streak.
  static const int requiredAdsForRestore = 3;

  Box? _box;

  Future<Box> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box(_boxName);
    } else {
      _box = await Hive.openBox(_boxName);
    }
    return _box!;
  }

  /// Ensures the box is open. Call once during app bootstrap.
  Future<void> init() async {
    await _openBox();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Current active streak (synchronous — requires [init] to have been called).
  int get currentStreak {
    final Box? b = _box;
    if (b == null || !b.isOpen) return 0;
    return (b.get(_kCurrentStreak, defaultValue: 0) as num).toInt();
  }

  /// Whether the user currently has an active streak freeze.
  bool get hasStreakFreeze {
    final Box? b = _box;
    if (b == null || !b.isOpen) return false;
    return b.get(_kHasStreakFreeze, defaultValue: false) as bool;
  }

  /// Whether a recently lost streak can still be restored.
  bool get canRestoreStreak {
    final Box? b = _box;
    if (b == null || !b.isOpen) return false;
    final dynamic lostAtRaw = b.get(_kLostStreakAt);
    final dynamic lostValueRaw = b.get(_kLostStreakValue, defaultValue: 0);
    if (lostAtRaw == null) return false;
    final DateTime? lostAt = _parseDate(lostAtRaw);
    if (lostAt == null) return false;
    if ((lostValueRaw as num).toInt() <= 0) return false;
    return DateTime.now().toUtc().difference(lostAt) <= _restoreWindow;
  }

  /// The UTC date (truncated to day) of the last recorded test, or `null`.
  DateTime? get lastTestDate {
    final Box? b = _box;
    if (b == null || !b.isOpen) return null;
    final dynamic raw = b.get(_kLastTestDate);
    return _parseDate(raw);
  }

  int get longestStreak {
    final Box? b = _box;
    if (b == null || !b.isOpen) return 0;
    return (b.get(_kLongestStreak, defaultValue: 0) as num).toInt();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the current streak. Opens the box if needed.
  Future<int> getCurrentStreak() async {
    final Box b = await _openBox();
    return (b.get(_kCurrentStreak, defaultValue: 0) as num).toInt();
  }

  /// Records a completed typing test and updates the streak accordingly.
  ///
  /// Logic (all dates compared in UTC, truncated to day):
  ///   - If no previous test: streak = 1.
  ///   - If already completed today: streak unchanged.
  ///   - If last test was yesterday: streak += 1.
  ///   - Otherwise (gap > 1 day):
  ///       - If a streak freeze is active AND the gap is exactly 2 days,
  ///         consume the freeze and increment the streak.
  ///       - Otherwise the previous streak is lost. The new streak becomes 1
  ///         and the previous value is stored for possible restoration.
  Future<StreakResult> recordTestCompletion() async {
    final Box b = await _openBox();

    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

    final DateTime? last = _parseDate(b.get(_kLastTestDate));
    final int oldStreak =
        (b.get(_kCurrentStreak, defaultValue: 0) as num).toInt();
    final int longest =
        (b.get(_kLongestStreak, defaultValue: 0) as num).toInt();
    final bool hasFreeze =
        b.get(_kHasStreakFreeze, defaultValue: false) as bool;

    int newStreak;
    bool streakFreezeUsed = false;
    bool streakLost = false;

    if (last == null) {
      newStreak = 1;
    } else {
      final int diffDays = today.difference(last).inDays;
      if (diffDays == 0) {
        // Already counted today.
        newStreak = oldStreak == 0 ? 1 : oldStreak;
      } else if (diffDays == 1) {
        newStreak = oldStreak + 1;
      } else if (diffDays == 2 && hasFreeze) {
        // Freeze covers one skipped day.
        newStreak = oldStreak + 1;
        streakFreezeUsed = true;
        await b.put(_kHasStreakFreeze, false);
        await b.delete(_kFreezeActivatedAt);
      } else {
        // Streak broken.
        streakLost = true;
        if (oldStreak > 0) {
          await b.put(_kLostStreakValue, oldStreak);
          await b.put(_kLostStreakAt, nowUtc.toIso8601String());
        }
        newStreak = 1;
      }
    }

    final bool isNewRecord = newStreak > longest;
    if (isNewRecord) {
      await b.put(_kLongestStreak, newStreak);
    }

    await b.put(_kCurrentStreak, newStreak);
    await b.put(_kLastTestDate, today.toIso8601String());

    return StreakResult(
      newStreak: newStreak,
      isNewRecord: isNewRecord,
      streakFreezeUsed: streakFreezeUsed,
      streakLost: streakLost,
    );
  }

  /// Activates a streak freeze that protects against a single missed day.
  Future<void> activateStreakFreeze() async {
    final Box b = await _openBox();
    await b.put(_kHasStreakFreeze, true);
    await b.put(
      _kFreezeActivatedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Attempts to restore a recently lost streak after the user has watched
  /// the required number of rewarded ads.
  ///
  /// Returns `true` if restoration succeeded.
  Future<bool> restoreStreak(int rewardedAdsWatched) async {
    if (rewardedAdsWatched < requiredAdsForRestore) return false;
    if (!canRestoreStreak) return false;

    final Box b = await _openBox();
    final int lostValue =
        (b.get(_kLostStreakValue, defaultValue: 0) as num).toInt();
    if (lostValue <= 0) return false;

    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);

    await b.put(_kCurrentStreak, lostValue);
    await b.put(_kLastTestDate, today.toIso8601String());
    await b.delete(_kLostStreakValue);
    await b.delete(_kLostStreakAt);

    final int longest =
        (b.get(_kLongestStreak, defaultValue: 0) as num).toInt();
    if (lostValue > longest) {
      await b.put(_kLongestStreak, lostValue);
    }
    return true;
  }

  /// Schedules a local notification reminder for the user to practice today
  /// and keep their streak alive. The actual notification is delegated to
  /// the app's notification service; this method persists the user's
  /// reminder preferences via SharedPreferences.
  Future<void> scheduleStreakReminder({
    int hour = 20,
    int minute = 0,
    bool enabled = true,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('streak_reminder_enabled', enabled);
    await prefs.setInt('streak_reminder_hour', hour);
    await prefs.setInt('streak_reminder_minute', minute);
    await prefs.setString(
      'streak_reminder_scheduled_at',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) {
      final DateTime? parsed = DateTime.tryParse(raw);
      return parsed?.toUtc();
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    return null;
  }
}
