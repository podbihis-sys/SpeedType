library leaderboard_entry;

class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int wpm;
  final double accuracy;
  final int rank;

  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.wpm,
    required this.accuracy,
    required this.rank,
  });
}
