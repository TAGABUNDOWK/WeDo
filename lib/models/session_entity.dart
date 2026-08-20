import 'package:cloud_firestore/cloud_firestore.dart';

/// Session status values.
enum SessionStatus {
  lobby,
  active,
  completed,
  cancelled;

  factory SessionStatus.fromString(String? value) {
    return SessionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SessionStatus.lobby,
    );
  }

  String get value => name;
}

/// Participant status values.
enum ParticipantStatus {
  active,
  finished;

  factory ParticipantStatus.fromString(String? value) {
    return ParticipantStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ParticipantStatus.active,
    );
  }

  String get value => name;
}

/// Document at `/sessions/{sessionId}`.
class SessionEntity {
  final String id;
  final String sessionId;
  final String hostId;
  final String topic;
  final SessionStatus status;
  final List<Map<String, dynamic>> cards;
  final String? speedShieldWinnerId;
  final Map<String, dynamic>? aggregatedResults;
  final List<String> invitedUserIds;
  final DateTime createdAt;
  final DateTime expiresAt;

  const SessionEntity({
    required this.id,
    required this.sessionId,
    required this.hostId,
    required this.topic,
    required this.status,
    required this.cards,
    this.speedShieldWinnerId,
    this.aggregatedResults,
    this.invitedUserIds = const [],
    required this.createdAt,
    required this.expiresAt,
  });

  factory SessionEntity.fromMap(String id, Map<String, dynamic> map) {
    return SessionEntity(
      id: id,
      sessionId: map['sessionId'] as String? ?? '',
      hostId: map['hostId'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      status: SessionStatus.fromString(map['status'] as String?),
      cards: (map['cards'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      speedShieldWinnerId: map['speedShieldWinnerId'] as String?,
      aggregatedResults: map['aggregatedResults'] as Map<String, dynamic>?,
      invitedUserIds: (map['invitedUserIds'] as List?)?.cast<String>() ?? const [],
      createdAt: _parseTimestamp(map['createdAt']),
      expiresAt: _parseTimestamp(map['expiresAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'hostId': hostId,
      'topic': topic,
      'status': status.value,
      'cards': cards,
      'speedShieldWinnerId': speedShieldWinnerId,
      'aggregatedResults': aggregatedResults,
      'invitedUserIds': invitedUserIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  SessionEntity copyWith({
    String? id,
    String? sessionId,
    String? hostId,
    String? topic,
    SessionStatus? status,
    List<Map<String, dynamic>>? cards,
    String? speedShieldWinnerId,
    Map<String, dynamic>? aggregatedResults,
    List<String>? invitedUserIds,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool clearSpeedShieldWinnerId = false,
    bool clearAggregatedResults = false,
    bool clearInvitedUserIds = false,
  }) {
    return SessionEntity(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      hostId: hostId ?? this.hostId,
      topic: topic ?? this.topic,
      status: status ?? this.status,
      cards: cards ?? this.cards,
      speedShieldWinnerId:
          clearSpeedShieldWinnerId ? null : (speedShieldWinnerId ?? this.speedShieldWinnerId),
      aggregatedResults:
          clearAggregatedResults ? null : (aggregatedResults ?? this.aggregatedResults),
      invitedUserIds:
          clearInvitedUserIds ? const [] : (invitedUserIds ?? this.invitedUserIds),
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
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
    return 'SessionEntity(id: $id, sessionId: $sessionId, hostId: $hostId, topic: $topic, '
        'status: ${status.value}, cards: $cards, '
        'speedShieldWinnerId: $speedShieldWinnerId, '
        'aggregatedResults: $aggregatedResults, '
        'invitedUserIds: $invitedUserIds)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Document at `/sessions/{sessionId}/participants/{userId}`.
class ParticipantEntity {
  final String id;
  final String userName;
  final ParticipantStatus status;
  final String? chosenWinnerCardId;
  final int? elapsedTimeMs;
  final List<String> eliminatedCardIds;
  final int timeoutCount;

  const ParticipantEntity({
    required this.id,
    required this.userName,
    required this.status,
    this.chosenWinnerCardId,
    this.elapsedTimeMs,
    required this.eliminatedCardIds,
    this.timeoutCount = 0,
  });

  factory ParticipantEntity.fromMap(String id, Map<String, dynamic> map) {
    return ParticipantEntity(
      id: id,
      userName: map['userName'] as String? ?? '',
      status: ParticipantStatus.fromString(map['status'] as String?),
      chosenWinnerCardId: map['chosenWinnerCardId'] as String?,
      elapsedTimeMs: map['elapsedTimeMs'] as int?,
      eliminatedCardIds: (map['eliminatedCardIds'] as List?)?.cast<String>() ?? const [],
      timeoutCount: map['timeoutCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'status': status.value,
      'chosenWinnerCardId': chosenWinnerCardId,
      'elapsedTimeMs': elapsedTimeMs,
      'eliminatedCardIds': eliminatedCardIds,
      'timeoutCount': timeoutCount,
    };
  }

  ParticipantEntity copyWith({
    String? id,
    String? userName,
    ParticipantStatus? status,
    String? chosenWinnerCardId,
    int? elapsedTimeMs,
    List<String>? eliminatedCardIds,
    int? timeoutCount,
    bool clearChosenWinnerCardId = false,
    bool clearElapsedTimeMs = false,
  }) {
    return ParticipantEntity(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      chosenWinnerCardId:
          clearChosenWinnerCardId ? null : (chosenWinnerCardId ?? this.chosenWinnerCardId),
      elapsedTimeMs:
          clearElapsedTimeMs ? null : (elapsedTimeMs ?? this.elapsedTimeMs),
      eliminatedCardIds: eliminatedCardIds ?? this.eliminatedCardIds,
      timeoutCount: timeoutCount ?? this.timeoutCount,
    );
  }

  @override
  String toString() {
    return 'ParticipantEntity(id: $id, userName: $userName, '
        'status: ${status.value}, chosenWinnerCardId: $chosenWinnerCardId, '
        'elapsedTimeMs: $elapsedTimeMs, eliminatedCardIds: $eliminatedCardIds, '
        'timeoutCount: $timeoutCount)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ParticipantEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
