library test_result;

/// Represents a completed typing test result.
///
/// Stores comprehensive metrics, metadata and user context so the
/// result can be persisted locally, synced to a backend, and rendered
/// on history, stats and leaderboard screens.
class TestResult {
  final String id;
  final double wpm;
  final double rawWpm;
  final double accuracy;
  final double consistency;
  final String targetText;
  final String typedText;
  final String mode;
  final String lang;
  final String level;
  final DateTime startTime;
  final DateTime endTime;
  final List<int> keystrokeTimestamps;
  final String? userId;
  final String? displayName;
  final bool isPersonalBest;
  final int? percentile;

  TestResult({
    required this.id,
    required this.wpm,
    required this.rawWpm,
    required this.accuracy,
    required this.consistency,
    required this.targetText,
    required this.typedText,
    required this.mode,
    required this.lang,
    required this.level,
    required this.startTime,
    required this.endTime,
    required this.keystrokeTimestamps,
    this.userId,
    this.displayName,
    this.isPersonalBest = false,
    this.percentile,
  });

  /// Convenience: elapsed duration of the test.
  Duration get duration => endTime.difference(startTime);

  /// Copy with overrides – useful when marking personal bests or
  /// attaching backend-computed percentile data after upload.
  TestResult copyWith({
    String? id,
    double? wpm,
    double? rawWpm,
    double? accuracy,
    double? consistency,
    String? targetText,
    String? typedText,
    String? mode,
    String? lang,
    String? level,
    DateTime? startTime,
    DateTime? endTime,
    List<int>? keystrokeTimestamps,
    String? userId,
    String? displayName,
    bool? isPersonalBest,
    int? percentile,
  }) {
    return TestResult(
      id: id ?? this.id,
      wpm: wpm ?? this.wpm,
      rawWpm: rawWpm ?? this.rawWpm,
      accuracy: accuracy ?? this.accuracy,
      consistency: consistency ?? this.consistency,
      targetText: targetText ?? this.targetText,
      typedText: typedText ?? this.typedText,
      mode: mode ?? this.mode,
      lang: lang ?? this.lang,
      level: level ?? this.level,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      keystrokeTimestamps: keystrokeTimestamps ?? this.keystrokeTimestamps,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isPersonalBest: isPersonalBest ?? this.isPersonalBest,
      percentile: percentile ?? this.percentile,
    );
  }

  /// Serialise to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wpm': wpm,
      'rawWpm': rawWpm,
      'accuracy': accuracy,
      'consistency': consistency,
      'targetText': targetText,
      'typedText': typedText,
      'mode': mode,
      'lang': lang,
      'level': level,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'keystrokeTimestamps': keystrokeTimestamps,
      'userId': userId,
      'displayName': displayName,
      'isPersonalBest': isPersonalBest,
      'percentile': percentile,
    };
  }

  /// Rehydrate from a JSON map. Tolerates ints posing as doubles and
  /// missing optional fields so legacy payloads keep deserialising.
  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      id: json['id'] as String,
      wpm: (json['wpm'] as num).toDouble(),
      rawWpm: (json['rawWpm'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      consistency: (json['consistency'] as num).toDouble(),
      targetText: json['targetText'] as String,
      typedText: json['typedText'] as String,
      mode: json['mode'] as String,
      lang: json['lang'] as String,
      level: json['level'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      keystrokeTimestamps: (json['keystrokeTimestamps'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      userId: json['userId'] as String?,
      displayName: json['displayName'] as String?,
      isPersonalBest: json['isPersonalBest'] as bool? ?? false,
      percentile: json['percentile'] as int?,
    );
  }

  @override
  String toString() =>
      'TestResult(id: $id, wpm: ${wpm.toStringAsFixed(1)}, '
      'acc: ${accuracy.toStringAsFixed(1)}%, mode: $mode, lang: $lang)';
}
