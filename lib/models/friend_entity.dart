import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  pending,
  friends;

  static FriendshipStatus fromString(String? value) {
    switch (value) {
      // Every spelling that has ever been written to `status` for an accepted
      // friendship. Documents created outside `acceptRequest` can carry one of
      // these, and the queries used to match only the literal 'friends' — so
      // those friendships were invisible while the user believed they existed.
      case 'friends':
      case 'accepted':
      case 'approved':
      case 'confirmed':
      case 'active':
        return FriendshipStatus.friends;
      default:
        return FriendshipStatus.pending;
    }
  }

  /// True for any value that is not an outstanding request.
  static bool isAcceptedValue(String? value) =>
      fromString(value) == FriendshipStatus.friends;

  String get value {
    switch (this) {
      case FriendshipStatus.friends:
        return 'friends';
      case FriendshipStatus.pending:
        return 'pending';
    }
  }
}

class FriendEntity {
  final String friendshipId;
  final List<String> userIds;
  final FriendshipStatus status;
  final String requestedBy;
  final DateTime updatedAt;

  const FriendEntity({
    required this.friendshipId,
    required this.userIds,
    required this.status,
    required this.requestedBy,
    required this.updatedAt,
  });

  factory FriendEntity.fromMap(String id, Map<String, dynamic> map) {
    final rawUserIds = map['userIds'];
    return FriendEntity(
      friendshipId: id,
      userIds: rawUserIds is List
          ? rawUserIds.whereType<String>().toList()
          : const <String>[],
      status: FriendshipStatus.fromString(map['status'] as String?),
      requestedBy: map['requestedBy'] as String? ?? '',
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  /// Tolerant by design: a single malformed `friends` document must not break
  /// the whole query. This previously threw `ArgumentError` on a missing or
  /// unrecognised `updatedAt`, which propagated out of the `snapshots().map()`
  /// in `FriendService` and errored the entire stream — the profile counter
  /// then silently fell back to `?? 0` and the list rendered empty.
  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  bool involves(String uid) => userIds.contains(uid);

  String otherUserId(String uid) {
    return userIds.firstWhere((id) => id != uid, orElse: () => '');
  }

  Map<String, dynamic> toMap() {
    return {
      'userIds': userIds,
      'status': status.value,
      'requestedBy': requestedBy,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FriendEntity(friendshipId: $friendshipId, userIds: $userIds, '
        'status: ${status.value}, requestedBy: $requestedBy)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendEntity && other.friendshipId == friendshipId;

  @override
  int get hashCode => friendshipId.hashCode;
}
