import 'package:hive_flutter/hive_flutter.dart';

/// Result returned when the user levels up.
class LevelUpResult {
  final String oldLevel;
  final String newLevel;
  final double averageWpm;

  const LevelUpResult({
    required this.oldLevel,
    required this.newLevel,
    required this.averageWpm,
  });

  Map<String, dynamic> toMap() => {
        'oldLevel': oldLevel,
        'newLevel': newLevel,
        'averageWpm': averageWpm,
      };

  @override
  String toString() =>
      'LevelUpResult(oldLevel: $oldLevel, newLevel: $newLevel, averageWpm: ${averageWpm.toStringAsFixed(1)})';
}

/// Service that handles per-language level progression based on recent WPM performance.
///
/// A user advances to the next level when the average WPM of their last
/// [_windowSize] tests meets or exceeds the threshold for the target level
/// in the given language.
class LevelProgressionService {
  LevelProgressionService._internal();

  static final LevelProgressionService _instance =
      LevelProgressionService._internal();

  factory LevelProgressionService() => _instance;
  static LevelProgressionService get instance => _instance;

  /// The ordered list of levels (lowest to highest).
  static const List<String> LEVELS = <String>[
    'beginner',
    'easy',
    'medium',
    'hard',
    'expert',
  ];

  /// Per-language WPM thresholds required to advance INTO a given level.
  ///
  /// Example: To advance from `beginner` to `easy` in English, the
  /// recent average WPM must meet or exceed `WPM_THRESHOLDS['en']!['easy']!`.
  static const Map<String, Map<String, double>> WPM_THRESHOLDS =
      <String, Map<String, double>>{
    'en': <String, double>{
      'beginner': 0.0,
      'easy': 25.0,
      'medium': 40.0,
      'hard': 60.0,
    },
    'de': <String, double>{
      'beginner': 0.0,
      'easy': 22.0,
      'medium': 36.0,
      'hard': 55.0,
    },
    'es': <String, double>{
      'beginner': 0.0,
      'easy': 24.0,
      'medium': 38.0,
      'hard': 58.0,
    },
    'fr': <String, double>{
      'beginner': 0.0,
      'easy': 23.0,
      'medium': 37.0,
      'hard': 56.0,
    },
    'pt': <String, double>{
      'beginner': 0.0,
      'easy': 24.0,
      'medium': 38.0,
      'hard': 57.0,
    },
  };

  /// The name of the Hive box that stores test history.
  static const String _testHistoryBoxName = 'test_history';

  /// The number of most recent tests to average for a level-up check.
  static const int _windowSize = 5;

  /// Lazily opens (or retrieves) the test history Hive box.
  Future<Box> _openTestHistoryBox() async {
    if (Hive.isBoxOpen(_testHistoryBoxName)) {
      return Hive.box(_testHistoryBoxName);
    }
    return Hive.openBox(_testHistoryBoxName);
  }

  /// Checks whether the user should level up in the given [lang] based on
  /// their recent test history. Returns a [LevelUpResult] if a level-up
  /// occurred, otherwise `null`.
  ///
  /// - [lang] is the language code (e.g. 'en', 'de').
  /// - [currentLevel] is the user's current level in that language.
  Future<LevelUpResult?> checkLevelUp(
    String lang,
    String currentLevel,
  ) async {
    if (isMaxLevel(currentLevel)) {
      return null;
    }

    final String? nextLevel = getNextLevel(currentLevel);
    if (nextLevel == null) {
      return null;
    }

    final Map<String, double>? langThresholds = WPM_THRESHOLDS[lang];
    if (langThresholds == null) {
      return null;
    }

    final double? threshold = langThresholds[nextLevel];
    if (threshold == null) {
      return null;
    }

    final Box box = await _openTestHistoryBox();

    // Collect all test records for the given language.
    final List<Map<dynamic, dynamic>> langTests = <Map<dynamic, dynamic>>[];
    for (final dynamic key in box.keys) {
      final dynamic raw = box.get(key);
      if (raw is Map) {
        final dynamic testLang = raw['lang'] ?? raw['language'];
        if (testLang == lang) {
          langTests.add(raw);
        }
      }
    }

    if (langTests.isEmpty) {
      return null;
    }

    // Sort by timestamp descending (most recent first). Missing timestamps
    // sort to the end.
    langTests.sort((Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
      final int aTs = _extractTimestamp(a);
      final int bTs = _extractTimestamp(b);
      return bTs.compareTo(aTs);
    });

    if (langTests.length < _windowSize) {
      return null;
    }

    final List<Map<dynamic, dynamic>> recent =
        langTests.take(_windowSize).toList();

    double sum = 0.0;
    int count = 0;
    for (final Map<dynamic, dynamic> t in recent) {
      final dynamic wpmRaw = t['wpm'];
      if (wpmRaw is num) {
        sum += wpmRaw.toDouble();
        count++;
      }
    }

    if (count < _windowSize) {
      return null;
    }

    final double avg = sum / count;

    if (avg >= threshold) {
      return LevelUpResult(
        oldLevel: currentLevel,
        newLevel: nextLevel,
        averageWpm: avg,
      );
    }

    return null;
  }

  int _extractTimestamp(Map<dynamic, dynamic> t) {
    final dynamic ts = t['timestamp'] ?? t['time'] ?? t['date'];
    if (ts is int) return ts;
    if (ts is String) {
      return DateTime.tryParse(ts)?.millisecondsSinceEpoch ?? 0;
    }
    if (ts is DateTime) return ts.millisecondsSinceEpoch;
    return 0;
  }

  /// Returns the level immediately following [currentLevel], or `null` if
  /// [currentLevel] is unknown or is already the maximum.
  String? getNextLevel(String currentLevel) {
    final int idx = LEVELS.indexOf(currentLevel);
    if (idx == -1) return null;
    if (idx >= LEVELS.length - 1) return null;
    return LEVELS[idx + 1];
  }

  /// Returns `true` when [level] is the highest level in [LEVELS].
  bool isMaxLevel(String level) {
    return level == LEVELS.last;
  }
}
