import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  audio,
  call,
  system,
  invite,
  event,
  poll,
  location;

  static MessageType fromString(String? value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'audio':
        return MessageType.audio;
      case 'call':
        return MessageType.call;
      case 'system':
        return MessageType.system;
      case 'invite':
        return MessageType.invite;
      case 'event':
        return MessageType.event;
      case 'poll':
        return MessageType.poll;
      case 'location':
        return MessageType.location;
      default:
        return MessageType.text;
    }
  }

  String get value {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.audio:
        return 'audio';
      case MessageType.call:
        return 'call';
      case MessageType.system:
        return 'system';
      case MessageType.invite:
        return 'invite';
      case MessageType.event:
        return 'event';
      case MessageType.poll:
        return 'poll';
      case MessageType.location:
        return 'location';
    }
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final String? imageUrl;
  final String? audioUrl;
  final int? durationSeconds;
  final String? activityId;
  final String? activityType;
  final String? callType;
  final String? callStatus;
  final String? refId;
  final List<String> readBy;
  final Map<String, dynamic> reactions;
  final bool edited;
  final DateTime createdAt;
  final Map<String, dynamic>? groupInviteData;
  final List<String> deletedFor;
  final String? replyTo;
  final String? replyToContent;
  final String? replyToSender;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime? liveUntil;
  final DateTime? updatedAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.imageUrl,
    this.audioUrl,
    this.durationSeconds,
    this.activityId,
    this.activityType,
    this.callType,
    this.callStatus,
    this.refId,
    required this.readBy,
    required this.reactions,
    required this.edited,
    required this.createdAt,
    this.groupInviteData,
    this.deletedFor = const [],
    this.replyTo,
    this.replyToContent,
    this.replyToSender,
    this.latitude,
    this.longitude,
    this.address,
    this.liveUntil,
    this.updatedAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    final senderId = data['senderId'] as String?
        ?? data['sender_id'] as String?
        ?? '';
    final senderName = data['senderName'] as String?
        ?? data['sender_name'] as String?
        ?? '';
    final content = data['content'] as String? ?? '';
    final type = MessageType.fromString(data['type'] as String?);
    final imageUrl = data['imageUrl'] as String?
        ?? data['image_url'] as String?;
    final audioUrl = data['audioUrl'] as String?
        ?? data['audio_url'] as String?;
    final durationSeconds = data['durationSeconds'] as int?
        ?? data['duration_seconds'] as int?;
    final activityId = data['activityId'] as String?;
    final activityType = data['activityType'] as String?;
    final callType = data['callType'] as String?
        ?? data['call_type'] as String?;
    final callStatus = data['callStatus'] as String?
        ?? data['call_status'] as String?;
    final refId = data['refId'] as String?
        ?? data['ref_id'] as String?;
    final readBy = (data['readBy'] as List?)
        ?? (data['read_by'] as List?)
        ?? const [];
    final reactions = Map<String, dynamic>.from(
        data['reactions'] as Map? ?? {});
    final edited = data['edited'] as bool? ?? false;
    final createdAt = _parseTimestamp(
        data['createdAt'] ?? data['created_at']);
    final groupInviteData = data['groupInviteData'] != null
        ? Map<String, dynamic>.from(data['groupInviteData'] as Map)
        : null;
    final deletedFor = (data['deleted_for'] as List?)?.cast<String>() ?? [];
    final replyTo = data['replyTo'] as String? ?? data['reply_to'] as String?;
    final replyToContent = data['replyToContent'] as String? ?? data['reply_to_content'] as String?;
    final replyToSender = data['replyToSender'] as String? ?? data['reply_to_sender'] as String?;
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    final address = data['address'] as String?;
    final liveUntil = _parseTimestampOrNull(data['liveUntil']);
    final updatedAt = _parseTimestampOrNull(data['updatedAt']);

    return ChatMessage(
      id: doc.id,
      senderId: senderId,
      senderName: senderName,
      content: content,
      type: type,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      activityId: activityId,
      activityType: activityType,
      callType: callType,
      callStatus: callStatus,
      refId: refId,
      readBy: readBy.cast<String>(),
      reactions: reactions,
      edited: edited,
      createdAt: createdAt,
      groupInviteData: groupInviteData,
      deletedFor: deletedFor,
      replyTo: replyTo,
      replyToContent: replyToContent,
      replyToSender: replyToSender,
      latitude: latitude,
      longitude: longitude,
      address: address,
      liveUntil: liveUntil,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    final live = liveUntil;
    final updated = updatedAt;
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.value,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'activityId': activityId,
      'activityType': activityType,
      'callType': callType,
      'callStatus': callStatus,
      'refId': refId,
      'readBy': readBy,
      'reactions': reactions,
      'edited': edited,
      'createdAt': Timestamp.fromDate(createdAt),
      if (groupInviteData != null) 'groupInviteData': groupInviteData,
      'deleted_for': deletedFor,
      if (replyTo != null) 'replyTo': replyTo,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
      if (live != null) 'liveUntil': Timestamp.fromDate(live),
      if (updated != null) 'updatedAt': Timestamp.fromDate(updated),
    };
  }

  bool get isRead => readBy.length > 1;

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  static DateTime? _parseTimestampOrNull(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
