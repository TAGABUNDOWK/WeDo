import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  friendRequest,
  friendRequestAccepted,
  eventCreated,
  pollCreated;

  factory NotificationType.fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationType.friendRequest,
    );
  }

  String get value => name;
}

enum NotificationStatus {
  pending,
  accepted,
  declined;

  factory NotificationStatus.fromString(String? value) {
    return NotificationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationStatus.pending,
    );
  }

  String get value => name;
}

class NotificationEntity {
  final String notificationId;
  final NotificationType type;
  final String title;
  final String message;
  final String? senderId;
  final String? relatedId;
  final String? groupId;
  final String? chatId;
  final String? otherUid;
  final bool isRead;
  final NotificationStatus status;
  final DateTime createdAt;

  const NotificationEntity({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.message,
    this.senderId,
    this.relatedId,
    this.groupId,
    this.chatId,
    this.otherUid,
    this.isRead = false,
    this.status = NotificationStatus.pending,
    required this.createdAt,
  });

  factory NotificationEntity.fromMap(String id, Map<String, dynamic> map) {
    return NotificationEntity(
      notificationId: id,
      type: NotificationType.fromString(map['type'] as String?),
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      senderId: map['sender_id'] as String?,
      relatedId: map['related_id'] as String?,
      groupId: map['group_id'] as String?,
      chatId: map['chat_id'] as String?,
      otherUid: map['other_uid'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      status: NotificationStatus.fromString(map['status'] as String?),
      createdAt: _parseTimestamp(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'message': message,
      'sender_id': senderId,
      'related_id': relatedId,
      'group_id': groupId,
      'chat_id': chatId,
      'other_uid': otherUid,
      'is_read': isRead,
      'status': status.value,
      'created_at': FieldValue.serverTimestamp(),
    };
  }

  NotificationEntity copyWith({
    String? notificationId,
    NotificationType? type,
    String? title,
    String? message,
    String? senderId,
    String? relatedId,
    String? groupId,
    String? chatId,
    String? otherUid,
    bool? isRead,
    NotificationStatus? status,
    DateTime? createdAt,
    bool clearSenderId = false,
    bool clearRelatedId = false,
    bool clearGroupId = false,
    bool clearChatId = false,
    bool clearOtherUid = false,
  }) {
    return NotificationEntity(
      notificationId: notificationId ?? this.notificationId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      senderId: clearSenderId ? null : (senderId ?? this.senderId),
      relatedId: clearRelatedId ? null : (relatedId ?? this.relatedId),
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      chatId: clearChatId ? null : (chatId ?? this.chatId),
      otherUid: clearOtherUid ? null : (otherUid ?? this.otherUid),
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
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
    return 'NotificationEntity(id: $notificationId, type: ${type.value}, '
        'title: $title, senderId: $senderId, isRead: $isRead, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEntity && other.notificationId == notificationId;

  @override
  int get hashCode => notificationId.hashCode;
}
