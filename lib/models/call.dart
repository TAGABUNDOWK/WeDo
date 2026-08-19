import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType {
  audio,
  video;

  static CallType fromString(String? value) {
    switch (value) {
      case 'video':
        return CallType.video;
      default:
        return CallType.audio;
    }
  }

  String get value => this == CallType.video ? 'video' : 'audio';
}

enum CallStatus {
  ringing,
  active,
  ended;

  static CallStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return CallStatus.active;
      case 'ended':
        return CallStatus.ended;
      default:
        return CallStatus.ringing;
    }
  }

  String get value {
    switch (this) {
      case CallStatus.ringing:
        return 'ringing';
      case CallStatus.active:
        return 'active';
      case CallStatus.ended:
        return 'ended';
    }
  }
}

class Call {
  final String id;
  final String? groupId;
  final String? chatId;
  final CallType type;
  final CallStatus status;
  final String createdBy;
  final List<String> members;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const Call({
    required this.id,
    this.groupId,
    this.chatId,
    required this.type,
    required this.status,
    required this.createdBy,
    required this.members,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  factory Call.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Call(
      id: doc.id,
      groupId: data['groupId'] as String?,
      chatId: data['chatId'] as String?,
      type: CallType.fromString(data['type'] as String?),
      status: CallStatus.fromString(data['status'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: _parseTimestamp(data['createdAt']),
      startedAt: data['startedAt'] != null
          ? _parseTimestamp(data['startedAt'])
          : null,
      endedAt: data['endedAt'] != null
          ? _parseTimestamp(data['endedAt'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'chatId': chatId,
      'type': type.value,
      'status': status.value,
      'createdBy': createdBy,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
