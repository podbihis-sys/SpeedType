import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result returned by [XpService.addXp].
class XpResult {
  final int xpEarned;
  final int newTotalXp;
  final int newLevel;
  final bool leveledUp;
  final String newLevelName;

  const XpResult({
    required this.xpEarned,
    required this.newTotalXp,
    required this.newLevel,
    required this.leveledUp,
    required this.newLevelName,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'xpEarned': xpEarned,
        'newTotalXp': newTotalXp,
        'newLevel': newLevel,
        'leveledUp': leveledUp,
        'newLevelName': newLevelName,
      };

  @override
  String toString() =>
      'XpResult(xpEarned: $xpEarned, newTotalXp: $newTotalXp, newLevel: $newLevel, leveledUp: $leveledUp, newLevelName: $newLevelName)';
}

/// Service that manages experience points (XP), account-level progression
/// and the optional double-XP booster.
///
/// XP is a monotonically-increasing counter. The current level is derived
/// from the total XP by scanning the per-level cost curve
/// [xpForLevel] (`level * level * 10`).
class XpService {
  XpService._internal();

  static final XpService _instance = XpService._internal();
  factory XpService() => _instance;
  static XpService get instance => _instance;

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  /// 50 ascending level titles, indexed 1..50.
  /// (Index 0 is a sentinel "Unranked" — [levelName] returns a title for level 1+).
  static const List<String> LEVEL_NAMES = <String>[
    'Unranked',
    'Rookie',
    'Beginner',
    'Novice',
    'Apprentice',
    'Initiate',
    'Learner',
    'Student',
    'Trainee',
    'Cadet',
    'Recruit',
    'Amateur',
    'Intermediate',
    'Practiced',
    'Skilled',
    'Proficient',
    'Adept',
    'Talented',
    'Expert',
    'Specialist',
    'Veteran',
    'Professional',
    'Seasoned',
    'Advanced',
    'Master',
    'Grandmaster',
    'Elite',
    'Champion',
    'Hero',
    'Virtuoso',
    'Prodigy',
    'Savant',
    'Legend',
    'Mythic',
    'Ascendant',
    'Immortal',
    'Sovereign',
    'Titan',
    'Overlord',
    'Conqueror',
    'Paragon',
    'Celestial',
    'Ethereal',
    'Mythical',
    'Divine',
    'Supreme',
    'Apex',
    'Pinnacle',
    'Transcendent',
    'Omniscient',
    'God',
  ];

  /// Maximum achievable level based on [LEVEL_NAMES].
  static int get maxLevel => LEVEL_NAMES.length - 1; // 50

  // --- Hive ---
  static const String _boxName = 'xp_data';

  // --- Keys ---
  static const String _kTotalXp = 'totalXp';
  static const String _kCurrentLevel = 'currentLevel';
  static const String _kDoubleXpActive = 'doubleXpActive';
  static const String _kDoubleXpRemaining = 'doubleXpTestsRemaining';

  /// How many tests the double-XP booster lasts for when activated.
  static const int _doubleXpDuration = 5;

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

  /// Ensures the Hive box is open. Call once during app bootstrap.
  Future<void> init() async {
    await _openBox();
  }

  // ---------------------------------------------------------------------------
  // XP math
  // ---------------------------------------------------------------------------

  /// Calculates the XP awarded for a single test.
  ///
  /// Formula: `round(wpm * (accuracy / 100) * 2)` — then doubled if
  /// [doubleXp] is true. Guaranteed to return at least `0`.
  int calculateXp(double wpm, double accuracy, {bool doubleXp = false}) {
    if (wpm <= 0) return 0;
    final double clampedAccuracy = accuracy.clamp(0.0, 100.0).toDouble();
    final double base = wpm * (clampedAccuracy / 100.0) * 2.0;
    int xp = base.round();
    if (xp < 0) xp = 0;
    if (doubleXp) xp *= 2;
    return xp;
  }

  /// XP required to complete [level] (i.e. the cost of the level itself,
  /// not the cumulative total). `xpForLevel(level) = level * level * 10`.
  int xpForLevel(int level) {
    if (level <= 0) return 0;
    return level * level * 10;
  }

  /// Cumulative XP required to reach the START of [level].
  int _cumulativeXpForLevel(int level) {
    if (level <= 1) return 0;
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += xpForLevel(i);
    }
    return total;
  }

  /// Derives the level reached by a given [totalXp] value.
  int levelFromTotalXp(int totalXp) {
    if (totalXp <= 0) return 1;
    int level = 1;
    int cumulative = 0;
    while (level < maxLevel) {
      cumulative += xpForLevel(level);
      if (totalXp < cumulative) break;
      level++;
    }
    return math.min(level, maxLevel);
  }

  /// Returns the human-readable title for [level].
  String levelName(int level) {
    if (level < 1) return LEVEL_NAMES[0];
    if (level >= LEVEL_NAMES.length) return LEVEL_NAMES.last;
    return LEVEL_NAMES[level];
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  int get totalXp {
    final Box? b = _box;
    if (b == null || !b.isOpen) return 0;
    return (b.get(_kTotalXp, defaultValue: 0) as num).toInt();
  }

  int get currentLevel {
    final Box? b = _box;
    if (b == null || !b.isOpen) return 1;
    final int stored = (b.get(_kCurrentLevel, defaultValue: 1) as num).toInt();
    return stored < 1 ? 1 : stored;
  }

  String get currentLevelName => levelName(currentLevel);

  bool get hasDoubleXp {
    final Box? b = _box;
    if (b == null || !b.isOpen) return false;
    final bool active = b.get(_kDoubleXpActive, defaultValue: false) as bool;
    if (!active) return false;
    return doubleXpTestsRemaining > 0;
  }

  int get doubleXpTestsRemaining {
    final Box? b = _box;
    if (b == null || !b.isOpen) return 0;
    return (b.get(_kDoubleXpRemaining, defaultValue: 0) as num).toInt();
  }

  /// XP required to complete the current level (the size of the current bar).
  int get xpForNextLevel => xpForLevel(currentLevel);

  /// Progress (0.0 .. 1.0) toward the next level.
  double get progressToNextLevel {
    if (currentLevel >= maxLevel) return 1.0;
    final int base = _cumulativeXpForLevel(currentLevel);
    final int into = totalXp - base;
    final int needed = xpForLevel(currentLevel);
    if (needed <= 0) return 1.0;
    return (into / needed).clamp(0.0, 1.0).toDouble();
  }

  // ---------------------------------------------------------------------------
  // Mutators
  // ---------------------------------------------------------------------------

  /// Adds [xp] to the user's total and returns the resulting [XpResult].
  /// Consumes one charge of the double-XP booster if active.
  Future<XpResult> addXp(int xp) async {
    final Box b = await _openBox();

    int awarded = xp < 0 ? 0 : xp;

    // Consume one booster charge (the caller is expected to have already
    // passed `doubleXp: true` to calculateXp when computing [xp], but we
    // still decrement the counter here so state stays consistent).
    final bool active = b.get(_kDoubleXpActive, defaultValue: false) as bool;
    int remaining =
        (b.get(_kDoubleXpRemaining, defaultValue: 0) as num).toInt();
    if (active && remaining > 0) {
      remaining -= 1;
      await b.put(_kDoubleXpRemaining, remaining);
      if (remaining <= 0) {
        await b.put(_kDoubleXpActive, false);
      }
    }

    final int oldTotal = (b.get(_kTotalXp, defaultValue: 0) as num).toInt();
    final int oldLevel =
        (b.get(_kCurrentLevel, defaultValue: 1) as num).toInt();

    final int newTotal = oldTotal + awarded;
    final int newLevel = levelFromTotalXp(newTotal);
    final bool leveledUp = newLevel > oldLevel;

    await b.put(_kTotalXp, newTotal);
    await b.put(_kCurrentLevel, newLevel);

    // Persist a lightweight mirror of the total so other parts of the app
    // (e.g. sync service) can read it without opening Hive.
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('xp_total', newTotal);
      await prefs.setInt('xp_level', newLevel);
    } catch (_) {
      // Shared prefs mirror is best-effort; ignore failures.
    }

    return XpResult(
      xpEarned: awarded,
      newTotalXp: newTotal,
      newLevel: newLevel,
      leveledUp: leveledUp,
      newLevelName: levelName(newLevel),
    );
  }

  /// Activates the double-XP booster for the next [_doubleXpDuration] tests.
  Future<void> activateDoubleXp() async {
    final Box b = await _openBox();
    await b.put(_kDoubleXpActive, true);
    await b.put(_kDoubleXpRemaining, _doubleXpDuration);
  }
}
