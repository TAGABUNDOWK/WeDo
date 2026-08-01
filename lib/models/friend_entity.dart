import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus {
  pending,
  friends;

  static FriendshipStatus fromString(String? value) {
    switch (value) {
      case 'friends':
        return FriendshipStatus.friends;
      default:
        return FriendshipStatus.pending;
    }
  }

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
    return FriendEntity(
      friendshipId: id,
      userIds: (map['userIds'] as List?)?.cast<String>() ?? const [],
      status: FriendshipStatus.fromString(map['status'] as String?),
      requestedBy: map['requestedBy'] as String? ?? '',
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    throw ArgumentError('Unsupported timestamp format: $value');
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
