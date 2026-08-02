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
    return DirectChat(
      id: doc.id,
      members: (data['members'] as List?)?.cast<String>() ?? const [],
      lastMessage: data['lastMessage'] as String?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastMessageAt: _parseTimestamp(data['lastMessageAt']),
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
