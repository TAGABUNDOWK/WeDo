/// Denormalized per-user game stats used by the leaderboard.
/// Stored at Firestore `userStats/{userId}`.
class UserStatsEntity {
  final String userId;
  final String displayName;
  final String? avatarAsset;
  final int totalMatchesPlayed;
  final int pickFightWins;
  final int triRaceWins;

  const UserStatsEntity({
    required this.userId,
    required this.displayName,
    this.avatarAsset,
    required this.totalMatchesPlayed,
    required this.pickFightWins,
    required this.triRaceWins,
  });

  factory UserStatsEntity.fromMap(String id, Map<String, dynamic> map) {
    return UserStatsEntity(
      userId: map['user_id'] as String? ?? id,
      displayName: map['display_name'] as String? ?? 'Player',
      avatarAsset: map['avatar_asset'] as String?,
      totalMatchesPlayed: (map['total_matches_played'] as num?)?.toInt() ?? 0,
      pickFightWins: (map['pick_fight_wins'] as num?)?.toInt() ?? 0,
      triRaceWins: (map['tri_race_wins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_asset': avatarAsset,
      'total_matches_played': totalMatchesPlayed,
      'pick_fight_wins': pickFightWins,
      'tri_race_wins': triRaceWins,
    };
  }

  int scoreFor(String field) {
    switch (field) {
      case 'pick_fight_wins':
        return pickFightWins;
      case 'tri_race_wins':
        return triRaceWins;
      default:
        return totalMatchesPlayed;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStatsEntity && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}