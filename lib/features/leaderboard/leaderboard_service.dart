library leaderboard_service;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/test_result.dart';

/// Time window filter for leaderboard queries.
enum LeaderboardPeriod { today, week, allTime }

/// A single row on the leaderboard UI.
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final double wpm;
  final double accuracy;
  final DateTime timestamp;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.wpm,
    required this.accuracy,
    required this.timestamp,
    required this.rank,
  });

  LeaderboardEntry copyWith({int? rank}) => LeaderboardEntry(
        userId: userId,
        displayName: displayName,
        wpm: wpm,
        accuracy: accuracy,
        timestamp: timestamp,
        rank: rank ?? this.rank,
      );

  /// Hydrate from a Firestore [DocumentSnapshot]. Missing fields fall
  /// back to sensible defaults so a single corrupt row doesn't break
  /// the whole list.
  factory LeaderboardEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    int rank = 0,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final ts = data['timestamp'];
    DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else if (ts is String) {
      timestamp = DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (ts is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      timestamp = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return LeaderboardEntry(
      userId: (data['userId'] as String?) ?? doc.id,
      displayName: (data['displayName'] as String?) ?? 'Anonymous',
      wpm: (data['wpm'] as num?)?.toDouble() ?? 0.0,
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: timestamp,
      rank: rank,
    );
  }
}

/// In-memory cached leaderboard payload with an expiry timestamp.
class CachedLeaderboard {
  final List<LeaderboardEntry> entries;
  final DateTime fetchedAt;

  const CachedLeaderboard({
    required this.entries,
    required this.fetchedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) >= LeaderboardService.cacheTtl;
}

/// Singleton façade over the `leaderboards` Firestore collection.
///
/// Results are cached in-memory for [cacheTtl] (5 minutes) keyed by
/// `lang_level_period`. Ranks are computed client-side based on list
/// position after the ordered Firestore query.
class LeaderboardService {
  LeaderboardService._internal();

  static final LeaderboardService _instance = LeaderboardService._internal();
  static LeaderboardService get instance => _instance;

  static const Duration cacheTtl = Duration(minutes: 5);
  static const int _defaultLimit = 100;

  final Map<String, CachedLeaderboard> _cache = <String, CachedLeaderboard>{};

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Fetch the top [limit] leaderboard entries for the given
  /// [lang]/[level]/[period]. Served from cache when fresh.
  Future<List<LeaderboardEntry>> getLeaderboard(
    String lang,
    String level,
    LeaderboardPeriod period, {
    int limit = _defaultLimit,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(lang, level, period);
    final cached = _cache[cacheKey];
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return cached.entries;
    }

    try {
      final query = _buildQuery(lang, level, period).limit(limit);
      final snapshot = await query.get();
      final entries = <LeaderboardEntry>[];
      for (var i = 0; i < snapshot.docs.length; i++) {
        entries.add(
          LeaderboardEntry.fromFirestore(snapshot.docs[i], rank: i + 1),
        );
      }
      _cache[cacheKey] = CachedLeaderboard(
        entries: entries,
        fetchedAt: DateTime.now(),
      );
      return entries;
    } catch (_) {
      // On failure, prefer serving stale cache over an empty list.
      if (cached != null) return cached.entries;
      return const <LeaderboardEntry>[];
    }
  }

  /// Returns the rank of [myWpm] within the leaderboard filtered by
  /// [lang]/[level]/[period] using Firestore's `count()` aggregation.
  ///
  /// Rank = (number of entries strictly greater than myWpm) + 1.
  Future<int> getMyRank(
    String lang,
    String level,
    LeaderboardPeriod period,
    double myWpm,
  ) async {
    try {
      final query = _buildQuery(lang, level, period)
          .where('wpm', isGreaterThan: myWpm);
      final agg = await query.count().get();
      final higher = agg.count ?? 0;
      return higher + 1;
    } catch (_) {
      return -1;
    }
  }

  /// Upload a freshly completed [TestResult] to the leaderboards
  /// collection. The score is written as **unverified** – a server-side
  /// Cloud Function (or similar) is expected to validate the keystroke
  /// data and flip `verified` to `true`.
  ///
  /// Path: `leaderboards/{lang_level_date}/scores/{userId_date}`
  Future<void> uploadScore(
    TestResult result,
    DateTime challengeDate,
  ) async {
    final userId = result.userId;
    if (userId == null || userId.isEmpty) {
      // Cannot upload without a signed-in user.
      return;
    }

    final dateKey = _formatDate(challengeDate);
    final parentId = '${result.lang}_${result.level}_$dateKey';
    final docId = '${userId}_$dateKey';

    final durationMs = result.endTime.difference(result.startTime).inMilliseconds;
    final keystrokeCount = result.keystrokeTimestamps.length;

    final payload = <String, dynamic>{
      'userId': userId,
      'displayName': result.displayName ?? 'Anonymous',
      'wpm': result.wpm,
      'rawWpm': result.rawWpm,
      'accuracy': result.accuracy,
      'consistency': result.consistency,
      'lang': result.lang,
      'level': result.level,
      'mode': result.mode,
      'challengeDate': dateKey,
      'timestamp': FieldValue.serverTimestamp(),
      'clientTimestamp': Timestamp.fromDate(result.endTime),
      'keystrokeCount': keystrokeCount,
      'testDuration': durationMs,
      'verified': false,
    };

    try {
      await _firestore
          .collection('leaderboards')
          .doc(parentId)
          .collection('scores')
          .doc(docId)
          .set(payload, SetOptions(merge: true));

      // Invalidate any cached board that could contain this new score.
      _invalidateCacheFor(result.lang, result.level);
    } catch (_) {
      // Swallow – offline queue will retry separately.
      rethrow;
    }
  }

  /// Drop all cached boards – useful after sign-in/sign-out or after a
  /// new score upload.
  void clearCache() => _cache.clear();

  // -------- helpers --------

  /// Builds the base `Query` for a given language/level/period. Today
  /// and week scopes target a single per-day collection (today) or use
  /// a collection-group query filtered by `challengeDate` for week.
  /// allTime queries the per-day subcollections via a collection group
  /// restricted by lang/level.
  Query<Map<String, dynamic>> _buildQuery(
    String lang,
    String level,
    LeaderboardPeriod period,
  ) {
    switch (period) {
      case LeaderboardPeriod.today:
        final dateKey = _formatDate(_todayUtc());
        final parentId = '${lang}_${level}_$dateKey';
        return _firestore
            .collection('leaderboards')
            .doc(parentId)
            .collection('scores')
            .orderBy('wpm', descending: true);

      case LeaderboardPeriod.week:
        final now = _todayUtc();
        final weekAgo = now.subtract(const Duration(days: 7));
        final weekAgoKey = _formatDate(weekAgo);
        return _firestore
            .collectionGroup('scores')
            .where('lang', isEqualTo: lang)
            .where('level', isEqualTo: level)
            .where('challengeDate', isGreaterThanOrEqualTo: weekAgoKey)
            .orderBy('challengeDate', descending: true)
            .orderBy('wpm', descending: true);

      case LeaderboardPeriod.allTime:
        return _firestore
            .collectionGroup('scores')
            .where('lang', isEqualTo: lang)
            .where('level', isEqualTo: level)
            .orderBy('wpm', descending: true);
    }
  }

  void _invalidateCacheFor(String lang, String level) {
    _cache.removeWhere((key, _) => key.startsWith('${lang}_${level}_'));
  }

  String _cacheKey(String lang, String level, LeaderboardPeriod period) =>
      '${lang}_${level}_${period.name}';

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
