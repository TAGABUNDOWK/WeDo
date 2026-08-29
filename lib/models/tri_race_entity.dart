import 'package:cloud_firestore/cloud_firestore.dart';

/// TriRace status values.
enum TriRaceStatus {
  lobby,
  started,
  finished,
  cancelled;

  factory TriRaceStatus.fromString(String? value) {
    return TriRaceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TriRaceStatus.lobby,
    );
  }

  String get value => name;
}

/// Document at `/triRaces/{raceId}`.
class TriRace {
  final String id;
  final String joinCode;
  final String hostId;
  final TriRaceStatus status;
  final int maxPlayers;
  final DateTime? raceStartedAt;
  final int? raceDurationMs;
  final DateTime createdAt;
  final String? deletedBy;
  final List<String> invitedUserIds;
  final List<String> participantUids;

  const TriRace({
    required this.id,
    required this.joinCode,
    required this.hostId,
    required this.status,
    this.maxPlayers = 4,
    this.raceStartedAt,
    this.raceDurationMs,
    required this.createdAt,
    this.deletedBy,
    this.invitedUserIds = const [],
    this.participantUids = const [],
  });

  factory TriRace.fromMap(String id, Map<String, dynamic> map) {
    return TriRace(
      id: id,
      joinCode: map['joinCode'] as String? ?? '',
      hostId: map['hostId'] as String? ?? '',
      status: TriRaceStatus.fromString(map['status'] as String?),
      maxPlayers: map['maxPlayers'] as int? ?? 4,
      raceStartedAt: map['raceStartedAt'] != null
          ? _parseTimestamp(map['raceStartedAt'])
          : null,
      raceDurationMs: map['raceDurationMs'] as int?,
      createdAt: _parseTimestamp(map['createdAt']),
      deletedBy: map['deletedBy'] as String?,
      invitedUserIds: (map['invitedUserIds'] as List?)?.cast<String>() ?? const [],
      participantUids: (map['participantUids'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'joinCode': joinCode,
      'hostId': hostId,
      'status': status.value,
      'maxPlayers': maxPlayers,
      if (raceStartedAt != null) 'raceStartedAt': Timestamp.fromDate(raceStartedAt!),
      if (raceDurationMs != null) 'raceDurationMs': raceDurationMs,
      'createdAt': Timestamp.fromDate(createdAt),
      if (deletedBy != null) 'deletedBy': deletedBy,
      'invitedUserIds': invitedUserIds,
      'participantUids': participantUids,
    };
  }

  TriRace copyWith({
    String? id,
    String? joinCode,
    String? hostId,
    TriRaceStatus? status,
    int? maxPlayers,
    DateTime? raceStartedAt,
    int? raceDurationMs,
    DateTime? createdAt,
    String? deletedBy,
    List<String>? invitedUserIds,
    List<String>? participantUids,
    bool clearRaceStartedAt = false,
    bool clearRaceDurationMs = false,
    bool clearDeletedBy = false,
  }) {
    return TriRace(
      id: id ?? this.id,
      joinCode: joinCode ?? this.joinCode,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      raceStartedAt: clearRaceStartedAt ? null : (raceStartedAt ?? this.raceStartedAt),
      raceDurationMs: clearRaceDurationMs ? null : (raceDurationMs ?? this.raceDurationMs),
      createdAt: createdAt ?? this.createdAt,
      deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
      invitedUserIds: invitedUserIds ?? this.invitedUserIds,
      participantUids: participantUids ?? this.participantUids,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  @override
  String toString() {
    return 'TriRace(id: $id, joinCode: $joinCode, hostId: $hostId, '
        'status: ${status.value}, maxPlayers: $maxPlayers)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TriRace && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Document at `/triRaces/{raceId}/participants/{userId}`.
class TriRaceParticipant {
  final String id;
  final String userId;
  final String username;
  final DateTime joinedAt;
  final String avatarColor;
  final double? speedSeed;
  final int? finishTimeMs;
  final int? placement;

  const TriRaceParticipant({
    required this.id,
    required this.userId,
    required this.username,
    required this.joinedAt,
    required this.avatarColor,
    this.speedSeed,
    this.finishTimeMs,
    this.placement,
  });

  factory TriRaceParticipant.fromMap(String id, Map<String, dynamic> map) {
    return TriRaceParticipant(
      id: id,
      userId: map['userId'] as String? ?? id,
      username: map['username'] as String? ?? '',
      joinedAt: _parseTimestamp(map['joinedAt']),
      avatarColor: map['avatarColor'] as String? ?? '#FFFFFF',
      speedSeed: (map['speedSeed'] as num?)?.toDouble(),
      finishTimeMs: map['finishTimeMs'] as int?,
      placement: map['placement'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'avatarColor': avatarColor,
      if (speedSeed != null) 'speedSeed': speedSeed,
      if (finishTimeMs != null) 'finishTimeMs': finishTimeMs,
      if (placement != null) 'placement': placement,
    };
  }

  TriRaceParticipant copyWith({
    String? id,
    String? userId,
    String? username,
    DateTime? joinedAt,
    String? avatarColor,
    double? speedSeed,
    int? finishTimeMs,
    int? placement,
    bool clearSpeedSeed = false,
    bool clearFinishTimeMs = false,
    bool clearPlacement = false,
  }) {
    return TriRaceParticipant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      joinedAt: joinedAt ?? this.joinedAt,
      avatarColor: avatarColor ?? this.avatarColor,
      speedSeed: clearSpeedSeed ? null : (speedSeed ?? this.speedSeed),
      finishTimeMs: clearFinishTimeMs ? null : (finishTimeMs ?? this.finishTimeMs),
      placement: clearPlacement ? null : (placement ?? this.placement),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  @override
  String toString() {
    return 'TriRaceParticipant(id: $id, username: $username, '
        'avatarColor: $avatarColor, placement: $placement, '
        'finishTimeMs: $finishTimeMs)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TriRaceParticipant && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
