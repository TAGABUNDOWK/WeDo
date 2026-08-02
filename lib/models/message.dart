import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  system;

  static MessageType fromString(String? value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'system':
        return MessageType.system;
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
      case MessageType.system:
        return 'system';
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
  final List<String> readBy;
  final Map<String, dynamic> reactions;
  final bool edited;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.imageUrl,
    required this.readBy,
    required this.reactions,
    required this.edited,
    required this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      content: data['content'] as String? ?? '',
      type: MessageType.fromString(data['type'] as String?),
      imageUrl: data['imageUrl'] as String?,
      readBy: (data['readBy'] as List?)?.cast<String>() ?? const [],
      reactions: Map<String, dynamic>.from(data['reactions'] as Map? ?? {}),
      edited: data['edited'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.value,
      'imageUrl': imageUrl,
      'readBy': readBy,
      'reactions': reactions,
      'edited': edited,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdAtLocal': DateTime.now().toIso8601String(),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
