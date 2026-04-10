library typing_engine;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/test_result.dart';

/// Core engine that drives a typing test session.
///
/// Holds the target text, the user's typed text, start / end time,
/// and per-keystroke timestamps. Exposes live metrics (wpm, rawWpm,
/// accuracy, cpm, consistency) and a [toResult] method to snapshot
/// the session into a persistable [TestResult].
class TypingEngine extends ChangeNotifier {
  TypingEngine({required String targetText})
      : _targetText = targetText,
        _uuid = const Uuid();

  final Uuid _uuid;

  String _targetText;
  String _typedText = '';
  DateTime? _startTime;
  DateTime? _endTime;
  final List<int> _keystrokeTimestamps = <int>[];

  /// Target text the user is expected to type.
  String get targetText => _targetText;

  /// Current typed text (what the user has entered so far).
  String get typedText => _typedText;

  /// When the first keystroke happened. Null until the user starts.
  DateTime? get startTime => _startTime;

  /// When the test completed. Null until [isComplete] is true.
  DateTime? get endTime => _endTime;

  /// Elapsed-ms timestamps (relative to [startTime]) for every keystroke.
  List<int> get keystrokeTimestamps => List.unmodifiable(_keystrokeTimestamps);

  /// True once the user has produced at least one keystroke.
  bool get hasStarted => _startTime != null;

  /// True once the user has typed the full target text length.
  bool get isComplete =>
      _typedText.length >= _targetText.length && _targetText.isNotEmpty;

  /// Update the target text (used when resetting with a new prompt).
  set targetText(String value) {
    _targetText = value;
    notifyListeners();
  }

  /// Called by the input field whenever the typed text changes.
  ///
  /// Records the first-keystroke timestamp, appends per-keystroke elapsed
  /// millis, caps the typed length to the target length, and fires the
  /// completion branch which stamps [endTime].
  void onTextChanged(String newText) {
    if (isComplete) return;

    // Cap typed text to target length – extra characters are ignored.
    if (newText.length > _targetText.length) {
      newText = newText.substring(0, _targetText.length);
    }

    // Start the clock on the very first meaningful change.
    _startTime ??= DateTime.now();

    final now = DateTime.now();
    final elapsedMs = now.difference(_startTime!).inMilliseconds;

    // Only record timestamps for *added* characters (not for backspace).
    if (newText.length > _typedText.length) {
      final added = newText.length - _typedText.length;
      for (var i = 0; i < added; i++) {
        _keystrokeTimestamps.add(elapsedMs);
      }
    }

    _typedText = newText;

    if (isComplete) {
      _endTime = now;
    }

    notifyListeners();
  }

  /// Elapsed seconds since the first keystroke.
  double get elapsedSeconds {
    if (_startTime == null) return 0.0;
    final end = _endTime ?? DateTime.now();
    return end.difference(_startTime!).inMilliseconds / 1000.0;
  }

  double get _elapsedMinutes {
    final s = elapsedSeconds;
    return s <= 0 ? 0.0 : s / 60.0;
  }

  /// Number of characters that match the target at the same position.
  int get _correctChars {
    var count = 0;
    final limit = math.min(_typedText.length, _targetText.length);
    for (var i = 0; i < limit; i++) {
      if (_typedText.codeUnitAt(i) == _targetText.codeUnitAt(i)) count++;
    }
    return count;
  }

  /// Words per minute based on *correct* characters / 5 / minutes.
  double get wpm {
    final minutes = _elapsedMinutes;
    if (minutes <= 0) return 0.0;
    return (_correctChars / 5.0) / minutes;
  }

  /// Raw WPM using every typed character (correct or not).
  double get rawWpm {
    final minutes = _elapsedMinutes;
    if (minutes <= 0) return 0.0;
    return (_typedText.length / 5.0) / minutes;
  }

  /// Accuracy as a percentage (correct / typed * 100). Returns 100 if
  /// nothing has been typed yet to avoid a flashing 0% before start.
  double get accuracy {
    if (_typedText.isEmpty) return 100.0;
    return (_correctChars / _typedText.length) * 100.0;
  }

  /// Characters per minute – the classic CPM metric (wpm * 5).
  double get cpm => wpm * 5.0;

  /// Consistency derived from the coefficient of variation of
  /// inter-keystroke intervals. Expressed as a 0-100 score where 100
  /// means perfectly even rhythm.
  double get consistency {
    if (_keystrokeTimestamps.length < 3) return 0.0;

    final intervals = <int>[];
    for (var i = 1; i < _keystrokeTimestamps.length; i++) {
      final diff = _keystrokeTimestamps[i] - _keystrokeTimestamps[i - 1];
      if (diff > 0) intervals.add(diff);
    }
    if (intervals.length < 2) return 0.0;

    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    if (mean <= 0) return 0.0;

    final variance = intervals
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        intervals.length;
    final stdDev = math.sqrt(variance);
    final cv = stdDev / mean; // coefficient of variation

    // Invert and clamp to 0..100. Lower CV → higher consistency.
    final score = (1.0 - cv) * 100.0;
    return score.clamp(0.0, 100.0);
  }

  /// Reset the engine so a new attempt can start fresh.
  void reset({String? newTargetText}) {
    if (newTargetText != null) _targetText = newTargetText;
    _typedText = '';
    _startTime = null;
    _endTime = null;
    _keystrokeTimestamps.clear();
    notifyListeners();
  }

  /// Snapshot the current engine state into a persistable [TestResult].
  ///
  /// Call at test completion – the caller supplies the session
  /// classification (mode/lang/level) since the engine itself is
  /// agnostic of those concerns.
  TestResult toResult({
    required String mode,
    required String lang,
    required String level,
    String? userId,
    String? displayName,
    bool isPersonalBest = false,
    int? percentile,
  }) {
    final start = _startTime ?? DateTime.now();
    final end = _endTime ?? DateTime.now();
    return TestResult(
      id: _uuid.v4(),
      wpm: wpm,
      rawWpm: rawWpm,
      accuracy: accuracy,
      consistency: consistency,
      targetText: _targetText,
      typedText: _typedText,
      mode: mode,
      lang: lang,
      level: level,
      startTime: start,
      endTime: end,
      keystrokeTimestamps: List<int>.from(_keystrokeTimestamps),
      userId: userId,
      displayName: displayName,
      isPersonalBest: isPersonalBest,
      percentile: percentile,
    );
  }
}
