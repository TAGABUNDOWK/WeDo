import 'package:cloud_firestore/cloud_firestore.dart';

class DirectChat {
  final String id;
  final List<String> members;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const DirectChat({
    required this.id,
    required this.members,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory DirectChat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Support both old flat format and new nested last_message format
    String? message;
    String? senderId;
    DateTime? sentAt;

    final lastMsg = data['last_message'];
    if (lastMsg is Map<String, dynamic>) {
      message = lastMsg['text'] as String?;
      senderId = lastMsg['senderId'] as String?;
      sentAt = _parseTimestamp(lastMsg['sentAt']);
    } else {
      message = data['lastMessage'] as String?;
      senderId = data['lastMessageSenderId'] as String?;
      sentAt = _parseTimestamp(data['lastMessageAt']);
    }

    return DirectChat(
      id: doc.id,
      members: (data['members'] as List?)?.cast<String>() ?? const [],
      lastMessage: message,
      lastMessageSenderId: senderId,
      lastMessageAt: sentAt,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  String otherUserId(String currentUid) {
    return members.firstWhere((id) => id != currentUid, orElse: () => '');
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DirectChat && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
