library user_profile;

class UserProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int totalTests;
  final int bestWpm;
  final double averageWpm;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.totalTests,
    required this.bestWpm,
    required this.averageWpm,
    required this.createdAt,
  });
}
