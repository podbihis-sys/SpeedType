library test_result;

class TestResult {
  final String id;
  final int wpm;
  final double accuracy;
  final int durationSeconds;
  final String language;
  final DateTime timestamp;

  TestResult({
    required this.id,
    required this.wpm,
    required this.accuracy,
    required this.durationSeconds,
    required this.language,
    required this.timestamp,
  });
}
