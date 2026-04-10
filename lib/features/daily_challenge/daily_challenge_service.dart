library daily_challenge_service;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/auth_service.dart';
import '../../data/local/local_text_service.dart';
import '../../data/sync/offline_queue.dart';
import '../../models/test_result.dart';

/// Immutable payload returned by [DailyChallengeService.getDailyChallenge].
///
/// [isOfflineFallback] indicates that the text came from the bundled
/// [LocalTextService] rather than Firestore (e.g. network error, missing
/// document, cold-start with no cache).
class DailyChallengeData {
  final String text;
  final String lang;
  final String level;
  final DateTime date;
  final bool isOfflineFallback;

  const DailyChallengeData({
    required this.text,
    required this.lang,
    required this.level,
    required this.date,
    this.isOfflineFallback = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'lang': lang,
        'level': level,
        'date': _formatDate(date),
        'isOfflineFallback': isOfflineFallback,
      };

  factory DailyChallengeData.fromJson(Map<String, dynamic> json) {
    return DailyChallengeData(
      text: json['text'] as String,
      lang: json['lang'] as String,
      level: json['level'] as String,
      date: DateTime.parse(json['date'] as String),
      isOfflineFallback: json['isOfflineFallback'] as bool? ?? false,
    );
  }
}

/// Singleton service that exposes the daily typing challenge text and
/// score submission APIs. It caches the daily text in [SharedPreferences]
/// so that repeat visits in the same day are instant and work offline.
class DailyChallengeService {
  DailyChallengeService._internal();

  static final DailyChallengeService _instance =
      DailyChallengeService._internal();
  static DailyChallengeService get instance => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _cachePrefix = 'daily';
  static const String _playedPrefix = 'daily_played';
  static const String _bestPrefix = 'daily_best';

  /// Returns the daily challenge for [lang]/[level]. The result is cached
  /// in [SharedPreferences] under `daily_<lang>_<level>_yyyy-MM-dd`.
  ///
  /// On any Firestore error (including missing doc) this falls back to
  /// [LocalTextService.instance.getSeededText] using today's date as the
  /// seed, and marks the result as [DailyChallengeData.isOfflineFallback].
  Future<DailyChallengeData> getDailyChallenge(
    String lang,
    String level,
  ) async {
    final today = _todayUtc();
    final dateKey = _formatDate(today);
    final cacheKey = '${_cachePrefix}_${lang}_${level}_$dateKey';

    final prefs = await SharedPreferences.getInstance();

    // 1. Cache hit: instant return.
    final cachedRaw = prefs.getString(cacheKey);
    if (cachedRaw != null) {
      try {
        final map = jsonDecode(cachedRaw) as Map<String, dynamic>;
        return DailyChallengeData.fromJson(map);
      } catch (_) {
        // Corrupt cache – fall through and refetch.
        await prefs.remove(cacheKey);
      }
    }

    // 2. Try Firestore:
    //    daily_challenges/{lang}/{level}/{yyyy-MM-dd}
    try {
      final doc = await _firestore
          .collection('daily_challenges')
          .doc(lang)
          .collection(level)
          .doc(dateKey)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final text = (data['text'] as String?) ?? '';
        if (text.isNotEmpty) {
          final challenge = DailyChallengeData(
            text: text,
            lang: lang,
            level: level,
            date: today,
            isOfflineFallback: false,
          );
          await prefs.setString(cacheKey, jsonEncode(challenge.toJson()));
          return challenge;
        }
      }
      // Fall through to fallback if doc missing or empty.
    } catch (_) {
      // Network/permission error – fall through to local fallback.
    }

    // 3. Local seeded fallback.
    return _fallbackChallenge(lang, level, today);
  }

  DailyChallengeData _fallbackChallenge(
    String lang,
    String level,
    DateTime date,
  ) {
    String text;
    try {
      final dynamic service = LocalTextService.instance;
      text = service.getSeededText(
        lang: lang,
        level: level,
        seed: _formatDate(date),
      ) as String;
    } catch (_) {
      text = '';
    }
    return DailyChallengeData(
      text: text,
      lang: lang,
      level: level,
      date: date,
      isOfflineFallback: true,
    );
  }

  /// Submit a score for the daily challenge. Anonymous users are skipped
  /// entirely (they can still play – the score is just not synced). The
  /// score is always stored locally and enqueued on the [OfflineQueue] so
  /// the sync layer can upload it when connectivity returns.
  Future<void> submitScore(
    TestResult result,
    DateTime challengeDate,
  ) async {
    // Skip anonymous users.
    if (_isAnonymous(result)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final dateKey = _formatDate(challengeDate);
    final bestKey = '${_bestPrefix}_${result.lang}_${result.level}_$dateKey';
    final playedKey =
        '${_playedPrefix}_${result.lang}_${result.level}_$dateKey';

    // Mark played.
    await prefs.setBool(playedKey, true);

    // Persist best locally.
    final prevBest = prefs.getDouble(bestKey) ?? 0.0;
    if (result.wpm > prevBest) {
      await prefs.setDouble(bestKey, result.wpm);
      await prefs.setString('${bestKey}_json', jsonEncode(result.toJson()));
    }

    // Enqueue for remote sync.
    try {
      final dynamic queue = OfflineQueue.instance;
      await queue.enqueue({
        'type': 'daily_challenge_score',
        'challengeDate': dateKey,
        'result': result.toJson(),
      });
    } catch (_) {
      // OfflineQueue not initialised yet – ignore so offline UX still works.
    }
  }

  /// Whether the current user already played today for [lang]/[level].
  Future<bool> hasPlayedToday(String lang, String level) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _formatDate(_todayUtc());
    final playedKey = '${_playedPrefix}_${lang}_${level}_$dateKey';
    return prefs.getBool(playedKey) ?? false;
  }

  /// Returns today's best WPM for [lang]/[level], or `null` if none yet.
  Future<double?> getTodaysBest(String lang, String level) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _formatDate(_todayUtc());
    final bestKey = '${_bestPrefix}_${lang}_${level}_$dateKey';
    return prefs.getDouble(bestKey);
  }

  // -------- internals --------

  bool _isAnonymous(TestResult result) {
    if (result.userId == null || result.userId!.isEmpty) return true;
    try {
      final dynamic auth = AuthService.instance;
      final dynamic anon = auth.isAnonymous;
      if (anon is bool) return anon;
    } catch (_) {
      // AuthService may not expose isAnonymous – fall back to userId check.
    }
    return false;
  }

  static DateTime _todayUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  static String _formatDate(DateTime date) {
    final d = date.toUtc();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }
}
